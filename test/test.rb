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

# 1
#puts Time.now.to_f

# 2
#filename = "tralalal_lala.jpg"
#puts File.extname(filename)

# 3 annotate
#require 'RMagick' 

#img = Magick::Image::read("test.jpg").first
#text = Magick::Draw.new 
#text.annotate(img, 0, 0, 10, 10, Time.now.strftime("ipd %e.%m.%Y, %H:%M")) { 
  #self.gravity = Magick::SouthEastGravity 
  #self.pointsize = 12 
  #self.stroke = 'transparent' 
  #self.fill = 'Orange' 
  #self.undercolor = 'DarkSlateBlue'
  #self.font = 'Helvetica'
  #self.font_weight = Magick::NormalWeight 
#} 
#img.write('test_w_text.jpg') 

# 4 extract exif data
#require 'date'
#img = Magick::Image::read("test.jpg").first
#date = img.get_exif_by_entry('DateTime')[0][1]
#puts DateTime.strptime(date, '%Y:%m:%d %H:%M:%S').to_time.to_i

# 5
#$:.unshift("/home/schommer/dev/indypicdump")
#require "./ipdconfig"
#require "./ipduser"

#user = IPDUser.new
#puts user.inspect
#puts user.accept_external_messages?
#user.accept_external_messages!
#puts user.inspect
#puts "--"
#puts user.decline_external_messages?
#user.decline_external_messages!
#puts user.inspect
#user.save
#puts "saved"
#puts user.inspect


# 6
#require "./ipdtest"
#puts IPDTest.mail.inspect

# 7
#require "./ipdconfig"
#puts IPDConfig::POP3_USER

# 8
#require "./ipdpicture"
#puts "nummer " + IPDPicture.get_random_id.to_s

# 9
#require "digest"
#puts Digest::RMD160::hexdigest("aljdbhgbsd,jnsd,fnsf,dfnsd,mfnsdf,mdsnf,dsf")
#puts Digest::SHA256::hexdigest("aljdbhgbsd,jnsd,fnsf,dfnsd,mfnsdf,mdsnf,dsf")

# 10
#require "sqlite3"
#require "./ipdconfig"
#require "./ipduser"
#user = IPDUser.new
#user.nick = "test"
#user.email = "mail1@test.org"
#user.email = "mail2@test.org"
#puts user.inspect
#user.save
#puts user.inspect
#user = IPDUser.load_by_email("mail1@test.org")
#puts user.inspect

# 11
#$:.unshift("/home/schommer/dev/indypicdump")
#require "./ipdconfig"
#require "./ipduser"

#user = IPDUser.new
#user.email = "test@somehost.com"
#user.accept_external_messages!
#puts user.inspect
#user.save
#puts user.inspect

#user = IPDUser.load_by_nick("poised apple")
#puts user.inspect
#user.accept_external_messages!
#user.remove_email("schommer@dingdong")
#user.email = "schommer@dingdong"
#puts user.inspect
#user.save

# 12
#require "./ipdconfig"
#require "./ipdrequest"

#request = IPDRequest.new
#request.action = "backe kuche"
#request.code = "milch zucker mehl"
#puts request.inspect
#request.save
#puts request.inspect

# 13
#message = "test some@mailbear.com. from to."
#regex = %r{([a-z0-9!#$\%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$\%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|asia|jobs|museum))\b}i
#puts message.sub(regex, '<a href=\"mailto:\1\">\1</a>')

# 14
#require 'ipdconfig'
#require 'ipdpicture'

#puts IPDPicture.load_by_id(35).inspect
#puts IPDPicture.load_by_filename("1353866445.6022875.jpg").inspect

# 15
#require 'ipdconfig'
#require 'ipddump'
#require 'ipdpicture'
#require 'ipduser'

#puts IPDPicture.load_by_id(35).inspect
#puts IPDUser.exists?("1")

#dump = IPDDump.load(9)
#puts dump.inspect
#puts dump.has_user?(1).inspect

# 16
#require 'ipdconfig'
#require 'ipderror'
#require 'ipddump'
#dump = IPDDump.load(9)
##dump.add_user("heino")
#dump.add_user(1)
