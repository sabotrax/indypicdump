#!/usr/bin/ruby -w

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
#require "./ipduser"

#user = IPDUser.new
#user.gen_nick
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
