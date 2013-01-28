#!/usr/bin/ruby -w

# This file is part of indypicdump.

# indypicdump is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# indypicdump is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with indypicdump.  If not, see <http://www.gnu.org/licenses/>.

# Copyright 2012 Marcus Schommer <sabotrax@gmail.com>

$:.unshift("/home/schommer/dev/indypicdump")

require 'mail'
require 'RMagick'
require 'sqlite3'
require 'date'
require 'stalker'
require 'ipdconfig'
require 'ipdpicture'
require 'ipdtest'
require 'ipduser'
require 'ipdmessage'
require 'ipddump'
require 'ipdrequest'
require 'ipdemail'
require 'ipderror'

IPDDump.load_dump_map

switch = ARGV.shift
if switch
  case switch
  when "test"
    test = true
  else
    puts "WRONG MODE (try \"test\")"
    exit
  end
end

##############################
# get mail
unless test
  Mail.defaults do
    retriever_method :pop3,
      :address    => IPDConfig::POP3_HOST,
      :port       => IPDConfig::POP3_PORT,
      :user_name  => IPDConfig::POP3_USER,
      :password   => IPDConfig::POP3_PASS,
      :enable_ssl => IPDConfig::POP3_SSL
  end
end

unless test
  mail = Mail.find_and_delete(:what => :first, :count => IPDConfig::FETCH_MAILS, :order => :asc, :delete_after_find => true)
  #mail = Mail.find(:what => :first, :count => IPDConfig::FETCH_MAILS, :order => :asc)
else
  mail = []
  mail.push(IPDTest.gen_mail)
end
IPDConfig::LOG_HANDLE.info("MAILS #{mail.length}/#{IPDConfig::FETCH_MAILS}")

picstack = []

mail.each do |m|

  ##############################
  # process user management mail
  if m.to[0] == IPDConfig::EMAIL_USER_MGMT
    case m.subject
      # i am
      when /(i am)\s+([a-z]+[\- ][a-z]+)/i
	nick = $2.undash
	if IPDUser.exists?(nick)
	  # check duplicate requests and ignore
	  request = IPDRequest.new
	  request.action = ["i am", nick, m.from[0]].join(",")
	  next if request.exists?
	  # check if requesting email address is already bound to this username
	  user = IPDUser.load(nick)
	  if user.has_email?(m.from[0])
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :i_am_already_are, :from => m.from[0], :nick => nick, :subject => "Notice")
	    next
	  end
	  # check if requesting email address is already bound to any username
	  result = IPDConfig::DB_HANDLE.execute("SELECT u.nick FROM user u JOIN mapping_user_email_address m ON u.id = m.id_user JOIN email_address e ON m.id_address = e.id WHERE e.address = ?", [m.from[0]])
	  if result.any?
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :i_am_some_is, :from => m.from[0], :nick => nick, :subject => "Notice")
	    next
	  end
	  # send request to owner of username
	  request.save
	  Stalker.enqueue("email.send", :to => user.email.first, :template => :i_am_request_code, :code => request.code, :from => m.from[0], :nick => nick, :subject => "Request to add email address")
	# send notification of non-existing user
	else
	  Stalker.enqueue("email.send", :to => m.from[0], :template => :i_am_no_user, :from => m.from[0], :nick => nick, :subject => "Notice")
	end
	next
      # accept/decline messages
      when /\b(accept|decline)\s+messages?\b/i
	order = $1.downcase
	if IPDUser.exists?(m.from[0])
	  # check duplicate requests and ignore
	  request = IPDRequest.new
	  request.action = ["#{order} messages", m.from[0]].join(",")
	  # NOTICE
	  # #exists? checks for existing accepts _and_ declines
	  next if request.exists?
	  # check if requesting user is already accepting/declining messages
	  user = IPDUser.load(m.from[0])
	  if (order == "accept" and user.accept_external_messages?) or (order == "decline" and user.decline_external_messages?)
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :messages_already_are, :nick => user.nick, :order => order, :subject => "Notice")
	    next
	  end
	  # send request
	  request.save
	  Stalker.enqueue("email.send", :to => m.from[0], :template => :messages_request_code, :code => request.code, :nick => user.nick, :order => order, :subject => "Request to #{order} messages")
	end
	next
      # open dump
      when /\bopen\s+([a-z0-9][a-z0-9\- ]*)(?<![\- ])\s+for\s+(#{IPDConfig::REGEX_EMAIL})/i
	address = $2.downcase
	if IPDUser.exists?(m.from[0])
	  user = IPDUser.load(m.from[0])
	  # check if dump exists
	  dump = IPDDump.load($1.dash)
	  unless dump
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :open_dump_no_dump, :nick => user.nick, :dump => $1.undash, :address => address, :subject => "Notice")
	    next
	  end
	  # check duplicate requests and ignore
	  request = IPDRequest.new
	  request.action = ["open dump", dump.alias, address].join(",")
	  next if request.exists?
	  # check if user is member of dump
	  unless dump.has_user?(user.id)
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :open_dump_no_member, :nick => user.nick, :dump => dump.alias.undash, :address => address, :subject => "Notice")
	    next
	  end
	  # check if new address is already member of dump
	  if user.has_email?(address)
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :bad_kitty, :nick => user.nick, :subject => "Notice")
	    next
	  end
	  if dump.has_user?(address)
	    Stalker.enqueue("email.send", :to => m.from[0], :template => :open_dump_already_are, :nick => user.nick, :dump => dump.alias.undash, :address => address, :subject => "Notice")
	    next
	  end
	  # send request
	  request.save
	  Stalker.enqueue("email.send", :to => m.from[0], :template => :open_dump_request_code, :code => request.code, :nick => user.nick, :dump => dump.alias.undash, :address => address, :subject => "Request to open dump")
	end
	next
      # did read
      when /\bdid\s+read\b/i
	if IPDUser.exists?(m.from[0])
	  user = IPDUser.load(m.from[0])
	  # remove messages older than the time of mailing
	  IPDMessage.remove_old(user.id, m.date.to_time.to_i)
	  IPDConfig::LOG_HANDLE.info("USER REQUEST DID READ #{m.from[0]}")
	end
	next
      # stats please
      when /\bstats\s+please\b/i
	if IPDUser.exists?(m.from[0])
	  user = IPDUser.load(m.from[0])
	  user_hash = {
	    :nick => user.nick,
	    :time_created => user.time_created,
	    :accept_messages => user.accept_external_messages?,
	  }
	  email_list = user.email
	  result = IPDConfig::DB_HANDLE.execute("SELECT d.id, d.alias FROM dump d JOIN mapping_dump_user m ON d.id = m.id_dump WHERE m.id_user= ? ORDER BY d.alias ASC", [user.id])
	  dump_list = []
	  picture_counter = 0
	  result.each do |row|
	    result2 = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM picture WHERE id_user = ? AND id_dump = ?", [user.id, row[0]])
	    picture_counter += result2[0][0]
	    dump_list.push({
	      :alias => row[1],
	      :picture_counter => result2[0][0]
	    })
	  end
	  # find the most common color of the newest picture
	  acc = []
	  if picture_counter != 0
	    result = IPDConfig::DB_HANDLE.execute("SELECT id FROM picture WHERE id_user = ? ORDER BY id DESC LIMIT 1", [user.id])
	    picture = IPDPicture.load(result[0][0])
	    begin
	      acc = picture.approx_common_color.slice(0, 2)
	    rescue PictureCommonColorMissing
	      IPDConfig::LOG_HANDLE.error("COMMON COLOR MISSING ERROR ID #{picture.id}")
	    end
	  end
	  Stalker.enqueue("email.send", :to => m.from[0], :template => :stats_please, :user => user_hash, :email => email_list, :dump => dump_list, :picture_counter => picture_counter, :common_color => acc, :subject => "Your stats")
	  IPDConfig::LOG_HANDLE.info("USER REQUEST STATS PLEASE #{m.from[0]}")
	end
    end
    next
  end
  if m.to[0] == IPDConfig::EMAIL_SELF
    body = ""
    if m.multipart?
      m.parts.each do |p|
	body += p.decoded if p.content_type.start_with?('text/')
      end
    else
      body = m.body.decoded
    end
    case body
      # work request codes
      when /request code (\h+)/im
	code = $1.downcase
	result = IPDConfig::DB_HANDLE.execute("SELECT action FROM user_request WHERE code LIKE ?", [code])
	if result.any?
	  action = result[0][0].split(",")
	  case action[0].downcase
	    # i am
	    when "i am"
	      # add address to requesting user
	      user = IPDUser.load(action[1])
	      user.email = action[2]
	      user.save
	      IPDRequest.remove_by_action(result[0][0])
	      IPDConfig::LOG_HANDLE.info("USER REQUEST BOUND ADDRESS TO USER #{action[2]} -> #{action[1]}")
	      next
	    # accept/decline messages
	    when /(accept|decline) messages/
	      order = $1
	      user = IPDUser.load(action[1])
	      if order == "accept"
		user.accept_external_messages!
	      elsif order == "decline"
		user.decline_external_messages!
	      end
	      user.save
	      IPDRequest.remove_by_action(result[0][0])
	      IPDConfig::LOG_HANDLE.info("USER REQUEST #{user.nick} #{order.upcase}S MESSAGES")
	      next
	    # open dump
	    when /open dump/
	      dump = IPDDump.load(action[1])
	      user = IPDUser.load(action[2])
	      # add known users to dump
	      if user
		dump.add_user(user.id)
		Stalker.enqueue("email.send", :to => action[2], :template => :open_dump_notice_invited, :nick => user.nick, :dump => dump.alias.undash, :subject => "A new place to store pictures")
		IPDRequest.remove_by_action(result[0][0])
		IPDConfig::LOG_HANDLE.info("USER REQUEST ADD USER #{user.nick} TO DUMP #{dump.alias}")
	      # invite new users
	      else
		IPDRequest.remove_by_action(result[0][0])
		request = IPDRequest.new
		action.shift
		request.action = ["new user", action].join(",")
		request.save
		action = request.action.split(",")
		Stalker.enqueue("email.send", :to => action[2], :template => :new_user_request_code, :code => request.code, :subject => "indypicdump - collect and share")
	      end
	      next
	    # new user
	    when /new user/
	      user = IPDUser.new
	      user.email = action[2]
	      user.save
	      dump = IPDDump.load(action[1])
	      dump.add_user(user.id)
	      Stalker.enqueue("email.send", :to => action[2], :template => :new_user_notice_invited, :dump => dump.alias.undash, :subject => "Welcome to indypicdump")
	      IPDRequest.remove_by_action(result[0][0])
	      IPDConfig::LOG_HANDLE.info("USER REQUEST NEW USER #{action[2]} IS #{user.nick} IN DUMP #{dump.alias}")
	      next
	    # create dump (and user)
	    when /create dump/
	      dump = IPDDump.new
	      dump.alias = action[1]
	      dump.save
	      user = IPDUser.new
	      user.email = action[2]
	      user.save
	      dump.add_user(user.id)
	      Stalker.enqueue("email.send", :to => action[2], :template => :new_user_notice_invited, :dump => dump.alias.undash, :subject => "Welcome to indypicdump")
	      IPDRequest.remove_by_action(result[0][0])
	      IPDConfig::LOG_HANDLE.info("USER REQUEST NEW DUMP #{dump.alias} BY #{action[2]} IS NEW USER #{user.nick}")
	      next
	  end
	else
	  # send error mail?
	end
    end
    next
  end

  m.attachments.each do | attachment |

    ##############################
    # extract picture attachments
    if (attachment.content_type.start_with?('image/'))
      # load user
      # CAUTION
      # "downcase" only works in the ASCII region
      email = m.from[0].downcase
      user = IPDUser.load(email)
      next unless user
      # drop pictures smaller than IPDConfig::PICTURE_MIN_SIZE
      img = Magick::Image::from_blob(attachment.body.decoded)[0]
      if img.columns >= img.rows and img.columns < IPDConfig::PICTURE_MIN_SIZE or img.rows >= img.columns and img.rows < IPDConfig::PICTURE_MIN_SIZE
	msg = IPDMessage.new
	msg.message_id = IPDConfig::MSG_PIC_TOO_SMALL
	msg.time_created = m.date.to_time.to_i
	msg.id_user = user.id
	msg.save
	IPDConfig::LOG_HANDLE.info("PICTURE TOO SMALL FROM #{user.nick} SIZE #{img.columns}x#{img.rows}")
	next
      end
      # check for existing dump
      unless IPDDump.exists?(m.to[0].to_s)
	msg = IPDMessage.new
	msg.message_id = IPDConfig::MSG_UNKNOWN_DUMP
	msg.time_created = m.date.to_time.to_i
	msg.id_user = user.id
	msg.save
	unknown_dump = m.to[0].to_s.downcase
	unknown_dump.sub!(/@.+$/, "")
	IPDConfig::LOG_HANDLE.info("UNKNOWN DUMP #{unknown_dump} FROM #{user.nick}")
	next
      end
      # check if user is member of dump
      dump = IPDDump.load(IPDDump.id_dump(m.to[0].to_s))
      unless dump.has_user?(user.id)
	msg = IPDMessage.new
	msg.message_id = IPDConfig::MSG_NO_DUMP_MEMBER
	msg.time_created = m.date.to_time.to_i
	msg.id_user = user.id
	msg.save
	IPDConfig::LOG_HANDLE.info("FORBIDDEN DUMP #{dump.alias} FROM #{user.nick}")
	next
      end
      # check for duplicate pictures
      # TODO
      # better use dump.has_picture?
      pic_hash = Digest::RMD160::hexdigest(attachment.body.encoded)
      #id_dump = IPDDump.id_dump(m.to[0].to_s)
      result = IPDConfig::DB_HANDLE.execute("SELECT id FROM \"#{dump.id}\" WHERE original_hash = ?", [pic_hash])
      if result.any?
	msg = IPDMessage.new
	msg.message_id = IPDConfig::MSG_DUPLICATE_PICTURE
	msg.time_created = m.date.to_time.to_i
	msg.id_user = user.id
	msg.save
	IPDConfig::LOG_HANDLE.info("DUPLICATE PICTURE FROM #{user.nick} ORIGINAL ID #{result[0][0]} DUMP #{dump.alias}")
	# CAUTION
	# we allow duplicates in test mode
	#next unless test
	next
      end

      IPDConfig::LOG_HANDLE.info("SENDER #{email}")
      # generate unique filename
      now = Time.now
      filename = now.to_f.to_s + File.extname(attachment.filename)
      path = Time.new(now.year, now.month, now.day).to_i.to_s
      pic = IPDPicture.new
      pic.filename = filename
      pic.time_sent = m.date.to_time.to_i
      pic.id_user = user.id
      pic.original_hash = pic_hash
      pic.id_dump = IPDDump.id_dump(m.to[0].to_s) if IPDDump.exists?(m.to[0].to_s)
      pic.path = path
      picstack.push(pic)
      begin
	File.open(IPDConfig::TMP_DIR + "/" + filename, "w+b", 0644) {|f| f.write attachment.body.decoded}
      rescue Exception => e
	IPDConfig::LOG_HANDLE.fatal("FILE SAVE ERROR #{user.email.to_s} / #{attachment.filename} / #{filename} / #{e.message} / #{e.backtrace.shift}")
      end
    end
    # only one pic per mail
    break
  end
end

##############################
# process pics

picstack.each do |picture|
  container = Magick::ImageList.new
  container.from_blob IO.read(IPDConfig::TMP_DIR + "/" + picture.filename)
  container.each do |img|
    # autoorient
    img.auto_orient!
    # read EXIF DateTime
    # EXIF DateTime is local time w/o time zone information
    date = img.get_exif_by_entry('DateTime')[0][1]
    if date =~ /^\d{4}:\d\d:\d\d \d\d:\d\d:\d\d$/
      # CAUTION
      # DateTime.to_time applies the local time zone
      # so we subtract the time zone offset from it
      time_taken = DateTime.strptime(date, '%Y:%m:%d %H:%M:%S').to_time
      picture.time_taken = time_taken.to_i - time_taken.gmt_offset
    end
    # resize
    if img.columns >= img.rows and img.columns > IPDConfig::PICTURE_MAX_HORZ_SIZE
      resize = IPDConfig::PICTURE_MAX_HORZ_SIZE
    elsif img.columns < img.rows and img.rows > IPDConfig::PICTURE_MAX_VERT_SIZE
      resize = IPDConfig::PICTURE_MAX_VERT_SIZE
    end
    img.resize_to_fit!(resize) if resize
    break unless picture.filename =~ /\.gif$/i
  end
  begin
    unless Dir.exists?(IPDConfig::PICTURE_DIR + "/" + picture.path)
      Dir.mkdir(IPDConfig::PICTURE_DIR + "/" + picture.path)
      IPDConfig::LOG_HANDLE.info("NEW DAY DIR #{picture.path}")
    end
    File.open(IPDConfig::PICTURE_DIR + "/" + picture.path + "/" + picture.filename, 'wb') { |f| f.write container.to_blob }
  rescue Exception => e
    IPDConfig::LOG_HANDLE.fatal("FILE COPY ERROR #{picture.filename} / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  # seems ok, so insert into db
  IPDConfig::DB_HANDLE.execute("INSERT INTO picture (filename, time_taken, time_sent, id_user, original_hash, id_dump, path) VALUES (?, ?, ?, ?, ?, ?, ?)", [picture.filename, picture.time_taken, picture.time_sent, picture.id_user, picture.original_hash, picture.id_dump, picture.path])
  # quantize
  Stalker.enqueue("picture.quantize", :filename => picture.filename)
  # delete tmp files 
  begin
    File.unlink(IPDConfig::TMP_DIR + "/" + picture.filename)
  rescue Exception => e
    IPDConfig::LOG_HANDLE.fatal("FILE DELETE ERROR #{picture.filename} / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  IPDConfig::LOG_HANDLE.info("ADD PICTURE #{picture.filename} DUMP #{picture.id_dump}")
end
