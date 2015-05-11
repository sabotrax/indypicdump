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

# Copyright 2012-2015 Marcus Schommer <sabotrax@gmail.com>

$:.unshift("#{File.dirname(__FILE__)}")

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
#$:.unshift("#{File.dirname(__FILE__)}")
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
#$:.unshift("#{File.dirname(__FILE__)}")
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

# 17
#require 'ipdconfig'
#require 'ipderror'
#require 'ipduser'
#user = IPDUser.new
#puts user.inspect
#user.save

# 18
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdrequest'
#request = IPDRequest.new
#puts request.inspect
#request.code = "lala"
#request.save

# 19
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdmessage'
#message = IPDMessage.new
#puts message.inspect
#message.save

# 19
#require 'ipdconfig'
#require 'ipderror'
#require 'ipddump'
#dump = IPDDump.new
#puts dump.inspect
#dump.save

# 20
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdrequest'
#request = IPDRequest.new
#puts request.exists?

# 21
#require 'RMagick'
#require 'sqlite3'
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdpicture'

#result = IPDConfig::DB_HANDLE.execute("SELECT id FROM picture")
#result.each do |row|
  #image = IPDPicture.load(row[0])
  #colors = image.quantize
  #puts colors.inspect
#end

#image = IPDPicture.load("1358882458.4065044.jpg")
#puts image.filename
#cc = image.quantize
#puts "3 MOST COMMON COLORS"
#puts cc.inspect

#cl = File.readlines(IPDConfig::PATH + "/data/list_of_colors.txt")
#colors = {}
#cl.each do |line|
  #a = line.split(",").map {|l| l.strip.chomp}
  #colors[a[0]] = a[1]
#end
#puts colors.inspect

# by rgb
#test = cc.first
#distance = 255 * 3
#approx_color = [0, 0, 0]
#colors.each_key do |color|
  #m = color.match(/#(..)(..)(..)/)
  #c = [m[1].hex, m[2].hex, m[3].hex]
  #r_dist = (test[0].abs2 - c[0].abs2).abs
  #g_dist = (test[1].abs2 - c[1].abs2).abs
  #b_dist = (test[2].abs2 - c[2].abs2).abs
  #new_distance = Math.sqrt(r_dist + g_dist + b_dist).to_i
  #if new_distance < distance
    #puts "#{new_distance}\t#{colors[color]}"
    #distance = new_distance
    #approx_color = color
  #end
#end
#puts colors[approx_color]

# 22
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdpicture'
#require 'stalker'
#picture = IPDPicture.load("1357641802.2345421.jpg")
#Stalker.enqueue("picture.quantize", :filename => picture.filename)

# 23
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdpicture'
#IPDPicture.delete(187)

# 24
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdpicture'
#picture = IPDPicture.load(102)
#puts picture.approx_common_color.inspect

# 25
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdpicture'
#picture = IPDPicture.new
#picture.save

# 25
#require 'ipdconfig'
#require 'ipderror'
#require 'ipdpicture'
#IPDPicture.get_weighted_random_id(9)

# 26
#require 'ipdconfig'
#require 'ipderror'
#require 'ipddump'
#dump = IPDDump.new
#dump.protect!
#puts dump.inspect

# 27
#require 'ipdconfig'
#require 'ipderror'
#require 'ipddump'
#dump = IPDDump.load(9)
#puts dump.inspect
#puts dump.has_user?("root@indypicdump.com")

# 28
#require 'ipdconfig'
#require 'ipderror'
#require 'ipddump'
#dump = IPDDump.new
#dump.alias = "testo"
#dump.add_user(1, :admin => 0, :time_created => 1361799405)
#dump.add_user(69, :admin => 1, :time_created => 1361799405)
#dump.save
#puts dump.inspect

# 39
#require 'ipdconfig'
#require 'ipderror'
#require 'ipddump'
#dump = IPDDump.load(19)
#puts dump.inspect
#dump.hide!
#dump.add_user(1, :admin => 1, :time_created => 1361799405)
#dump.add_user(68, :admin => 0, :time_created => 1361799405)
#puts dump.inspect
#dump.save
#puts dump.inspect

# 40
require 'ipdconfig'
require 'ipderror'
require 'ipddump'
require 'ipduser'
user = IPDUser.load(1)
puts user.inspect
puts user.admin_of_dump?("foo")
