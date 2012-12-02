#!/usr/bin/ruby -w

# This file is part of indypicdump.

# Foobar is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Foobar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

# Copyright 2012 Marcus Schommer <sabotrax@gmail.com>

require 'mail'
require 'RMagick'
require 'sqlite3'
require 'date'
require 'logger'
require '/home/schommer/dev/indypicdump/ipdconfig'
require '/home/schommer/dev/indypicdump/ipdpicture'
require '/home/schommer/dev/indypicdump/ipdtest'
require '/home/schommer/dev/indypicdump/ipduser'

log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
log.level = IPDConfig::LOG_LEVEL

switch = ARGV.shift
if switch
  if switch != "test"
    puts "WRONG MODE (try \"test\")"
    exit
  else
    puts "MODE #{switch}"
  end
end

##############################
# get mail
unless switch
  Mail.defaults do
    retriever_method :pop3,
      :address    => IPDConfig::POP3_HOST,
      :port       => IPDConfig::POP3_PORT,
      :user_name  => IPDConfig::POP3_USER,
      :password   => IPDConfig::POP3_PASS,
      :enable_ssl => true
  end
end

unless switch
  # TODO
  # is "asc" newest or oldest first? should be oldest
  mail = Mail.find(:what => :first, :count => IPDConfig::FETCH_MAILS, :order => :asc)
else
  mail = []
  mail.push(IPDTest.gen_mail)
end
log.info("MAILS #{mail.length}/#{IPDConfig::FETCH_MAILS}")

picstack = []

##############################
# extract picture attachements

mail.each do |m|
  m.attachments.each do | attachment |
    if (attachment.content_type.start_with?('image/'))
      # load or generate user
      # CAUTION
      # "downcase" only works in the ASCII region
      email = m.from[0].downcase
      user = IPDUser.load(email)
      log.info("SENDER #{email}")
      unless user
	user = IPDUser.new
	user.gen_nick
	user.email = email
	user.save
	log.info("IS NEW USER \"#{user.nick}\"")
      end
      # generate unique filename
      filename = Time.now.to_f.to_s + File.extname(attachment.filename)
      pic = IPDPicture.new
      pic.filename = filename
      # we have no "date" in test mode
      if m.date
	pic.time_send = m.date.to_time.to_i
      else
	pic.time_send =  Time.now.to_i
      end
      pic.id_user = user.id
      picstack.push(pic)
      begin
	File.open(IPDConfig::TMP_DIR + "/" + filename, "w+b", 0644) {|f| f.write attachment.body.decoded}
      rescue Exception => e
	log.fatal("FILE SAVE ERROR #{user.email} / #{attachment.filename} / #{filename} / #{e.message} / #{e.backtrace.shift}")
      end
    end
    # TODO
    # test
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
  # read exif DateTime
  date = img.get_exif_by_entry('DateTime')[0][1]
  if date
    pic.time_taken = DateTime.strptime(date, '%Y:%m:%d %H:%M:%S').to_time.to_i
  end
  # resize
  if img.columns >= img.rows and img.columns > 800
    resize = 800
  elsif img.columns < img.rows and img.rows > 800
    resize = 600
  end
  img.resize_to_fit!(resize) if resize
  begin
   img.write(IPDConfig::PIC_DIR + "/" + pic.filename)
  rescue Exception => e
    log.fatal("FILE COPY ERROR #{pic.filename} / #{e.message} / #{e.backtrace.shift}")
  end
  # seems ok, so insert into db
  IPDConfig::DB_HANDLE.execute("INSERT INTO picture (filename, time_taken, time_send, id_user) VALUES (?, ?, ?, ?)", [pic.filename, pic.time_taken, pic.time_send, pic.id_user])
  # delete tmp files 
  begin
    File.unlink(IPDConfig::TMP_DIR + "/" + pic.filename)
  rescue Exception => e
    log.fatal("FILE DELETE ERROR #{pic.filename} / #{e.message} / #{e.backtrace.shift}")
  end
  log.info("ADD PICTURE #{pic.filename}")
end

log.close
