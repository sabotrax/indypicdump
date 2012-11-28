#!/usr/bin/ruby -w

require 'rubygems'
require 'mail'
require 'RMagick'
require 'sqlite3'
require 'date'
require '/home/schommer/dev/indypicdump/ipdconfig'
require '/home/schommer/dev/indypicdump/ipdpicture'
require '/home/schommer/dev/indypicdump/ipdtest'
require '/home/schommer/dev/indypicdump/ipduser'

switch = ARGV.shift
if switch
  if switch != "test"
    puts "WRONG MODE (try \"test\")"
    exit
  else
    puts "MODE #{switch}"
  end
end

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
  mail = Mail.all
else
  mail = []
  mail.push(IPDTest.gen_mail)
end
puts "MAILS " + mail.length.to_s

picstack = []

# extract picture attachements

mail.each do |m|
  m.attachments.each do | attachment |
    if (attachment.content_type.start_with?('image/'))
      # load or generate user
      email = m.from[0]
      puts "SENDER " + email
      user = IPDUser.load(email)
      unless user
	puts "NEW"
	user = IPDUser.new
	user.gen_nick
	user.email = email
	user.save
      end
      puts "USER META"
      puts user.inspect
      # generate unique filename
      filename = Time.now.to_f.to_s + File.extname(attachment.filename)
      pic = IPDPicture.new
      pic.filename = filename
      # we have no "date" in test mode
      if m.date
	#puts "DATE FROM PIC"
	pic.time_send = m.date.to_time.to_i
      else
	#puts "FAKE DATE"
	pic.time_send =  Time.now.to_i
      end
      pic.id_user = user.id
      picstack.push(pic)
      begin
	File.open(IPDConfig::TMP_DIR + "/" + filename, "w+b", 0644) {|f| f.write attachment.body.decoded}
      rescue Exception => e
	puts "Unable to save data for #{filename} because #{e.message}"
      end
    end
    # TODO
    # test
    # only one pic per mail
    break
  end
end

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
   puts "Unable to save data for #{pic.filename} because #{e.message}"
  end
  # seems ok, so insert into db
  IPDConfig::DB_HANDLE.execute("INSERT INTO picture (filename, time_taken, time_send, id_user) VALUES (?, ?, ?, ?)", [pic.filename, pic.time_taken, pic.time_send, pic.id_user])
  # delete tmp files 
  begin
    File.unlink(IPDConfig::TMP_DIR + "/" + pic.filename)
  rescue Exception => e
    puts "Unable to unlink file #{pic.filename} because #{e.message}"
  end
  puts "PIC META"
  puts pic.inspect
end

puts "----------"
