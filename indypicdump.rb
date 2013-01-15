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
require 'securerandom'
require 'ipdconfig'
require 'ipdpicture'
require 'ipdtest'
require 'ipduser'
require 'ipdmessage'
require 'ipddump'
require 'ipdrequest'

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
  # TODO
  # is "asc" newest or oldest first? should be oldest
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
	  action = ["i am", nick, m.from[0]].join(",")
	  result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user_request WHERE action = ?", [action])
	  next if result.any?
	  # check if requesting email address is already bound to this username
	  already_are = false
	  result = IPDConfig::DB_HANDLE.execute("SELECT e.address, u.nick FROM email_address e JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE u.nick = ? ORDER BY e.time_created ASC", [nick])
	  result.each do |row|
	    if row[0] == m.from[0]
	      Stalker.enqueue("email.send", :to => m.from[0], :template => :i_am_already_are, :from => m.from[0], :nick => nick, :subject => "Notice")
	      already_are = true
	      break
	    end
	  end
	  next if already_are
	  # check if requesting email address is already bound to any username and expand request mail
	  result2 = IPDConfig::DB_HANDLE.execute("SELECT u.nick FROM user u JOIN mapping_user_email_address m ON u.id = m.id_user JOIN email_address e ON m.id_address = e.id WHERE e.address = ?", [m.from[0]])
	  bound_to = ""
	  bound_to = result2[0][0] if result2.any?
	  # send request to owner of username
	  request_code = SecureRandom.hex(16).downcase
	  IPDConfig::DB_HANDLE.execute("INSERT INTO user_request (action, code, time_created) VALUES (?, ?, ?)", [action, request_code, Time.now.to_i]) 
	  Stalker.enqueue("email.send", :to => result[0][0], :template => :i_am_request_code, :code => request_code, :from => m.from[0], :nick => nick, :bound_to => bound_to, :subject => "Request to add email address")
	else
	  Stalker.enqueue("email.send", :to => m.from[0], :template => :i_am_no_user, :from => m.from[0], :nick => nick, :subject => "Notice")
	end
	# TODO
	# append next because of loose regexps?
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
	# TODO
	# append next because of loose regexps?
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
	# TODO
	# append next because of loose regexps?
      else
	# i do not understand $1?
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
	      begin
		# update mapping of email addresses to users
		IPDConfig::DB_HANDLE.transaction
		# TODO
		# better load user
		result = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", [action[1]])
		id_user = result[0][0]
		result = IPDConfig::DB_HANDLE.execute("SELECT id FROM email_address WHERE address = ?", [action[2]])
		id_address = result[0][0] if result.any?
		# save new addresses
		if result.empty?
		  # TODO
		  # better IPDUser.add_email_address
		  IPDConfig::DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [action[2], Time.now.to_i])
		  result2 = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
		  IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [id_user, result2[0][0]])
		# update existing
		else
		  # TODO
		  # better IPDUser.add_email_address - to other user -> IPDUser.move_email_address?
		  result2 = IPDConfig::DB_HANDLE.execute("SELECT id_user FROM mapping_user_email_address WHERE id_address = ?", [id_address])
		  IPDConfig::DB_HANDLE.execute("UPDATE mapping_user_email_address SET id_user = ? WHERE id_user = ? AND id_address = ?", [id_user, result2[0][0], id_address])
		end
		IPDConfig::DB_HANDLE.execute("DELETE FROM user_request WHERE code LIKE ?", [$1.downcase])
		IPDConfig::LOG_HANDLE.info("USER REQUEST BOUND ADDRESS TO USER #{action[2]} -> #{action[1]}")
	      rescue SQLite3::Exception => e
		IPDConfig::DB_HANDLE.rollback
		IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE UPDATING USER EMAIL MAPPING #{action.to_s} / #{e.message} / #{e.backtrace.shift}")
		raise
	      end
	      IPDConfig::DB_HANDLE.commit
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
		IPDConfig::LOG_HANDLE.info("ADD USER #{user.nick} TO DUMP #{dump.alias}")
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
	      IPDConfig::LOG_HANDLE.info("NEW USER #{action[2]} IS #{user.nick} DUMP #{dump.alias}")
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
	next unless test
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

picstack.each do |pic|
  # autoorient
  img = Magick::Image::read(IPDConfig::TMP_DIR + "/" + pic.filename).first
  img.auto_orient!
  # read EXIF DateTime
  # EXIF DateTime is local time w/o time zone information
  date = img.get_exif_by_entry('DateTime')[0][1]
  if date =~ /^\d{4}:\d\d:\d\d \d\d:\d\d:\d\d$/
    # CAUTION
    # DateTime.to_time applies the local time zone
    # so we subtract the time zone offset from it
    time_taken = DateTime.strptime(date, '%Y:%m:%d %H:%M:%S').to_time
    pic.time_taken = time_taken.to_i - time_taken.gmt_offset
  end
  # resize
  if img.columns >= img.rows and img.columns > 800
    resize = 800
  elsif img.columns < img.rows and img.rows > 600
    resize = 600
  end
  img.resize_to_fit!(resize) if resize
  begin
    unless Dir.exists?(IPDConfig::PICTURE_DIR + "/" + pic.path)
      Dir.mkdir(IPDConfig::PICTURE_DIR + "/" + pic.path)
      IPDConfig::LOG_HANDLE.info("NEW DAY DIR #{pic.path}")
    end
    img.write(IPDConfig::PICTURE_DIR + "/" + pic.path + "/" + pic.filename)
  rescue Exception => e
    IPDConfig::LOG_HANDLE.fatal("FILE COPY ERROR #{pic.filename} / #{e.message} / #{e.backtrace.shift}")
  end
  # seems ok, so insert into db
  IPDConfig::DB_HANDLE.execute("INSERT INTO picture (filename, time_taken, time_sent, id_user, original_hash, id_dump, path) VALUES (?, ?, ?, ?, ?, ?, ?)", [pic.filename, pic.time_taken, pic.time_sent, pic.id_user, pic.original_hash, pic.id_dump, pic.path])
  # delete tmp files 
  begin
    File.unlink(IPDConfig::TMP_DIR + "/" + pic.filename)
  rescue Exception => e
    IPDConfig::LOG_HANDLE.fatal("FILE DELETE ERROR #{pic.filename} / #{e.message} / #{e.backtrace.shift}")
  end
  IPDConfig::LOG_HANDLE.info("ADD PICTURE #{pic.filename} DUMP #{pic.id_dump}")
end
