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

require 'stalker'
require 'mail'
require 'slim'
require 'ipdconfig'
require 'ipdhelper'
require 'ipdpicture'
include Stalker

##############################
job 'email.send' do |args|
  class Env
    attr_accessor :from, :nick, :code, :order, :message, :path, :filename, :dump, :address, :user, :email, :picture_counter, :common_color, :pictures, :now
  end
  env = Env.new
  env.from = args["from"]
  env.nick = args["nick"]
  env.code = args["code"]
  env.order = args["order"]
  env.message = args["message"]
  env.path = args["path"]
  env.filename = args["filename"]
  env.dump = args["dump"]
  env.address = args["address"]
  env.user = args["user"]
  env.email = args["email"]
  env.picture_counter = args["picture_counter"]
  env.common_color = args["common_color"]
  env.pictures = args["pictures"]
  env.now = args["now"]
  template_file = IPDConfig::TEMPLATE_DIR + "/mail_#{args['template']}.slim"
  template = Slim::Template.new(template_file, :pretty => IPDConfig::RENDER_PRETTY)
  body = template.render(env)
  mail = Mail.new do
    from IPDConfig::EMAIL_SELF
    to args['to']
    subject args["subject"] || "Info"
    html_part do
      content_type "text/html; charset=UTF-8"
      body body
    end
  end
  mail.delivery_method :sendmail
  mail.deliver
end

##############################
job 'user_requests.remove_stale' do
  now = Time.now
  try = 0
  begin
    IPDConfig::DB_HANDLE.transaction if try == 0
    result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user_request WHERE time_created < ?", [now.to_i - IPDConfig::REQUEST_ACCEPT_SPAN])
    if result.any?
      IPDConfig::DB_HANDLE.execute("DELETE FROM user_request WHERE time_created < ?", [now.to_i - IPDConfig::REQUEST_ACCEPT_SPAN])
      IPDConfig::LOG_HANDLE.info("REMOVE STALE USER REQUESTS #{result.size}")
    end
  rescue SQLite3::BusyException => e
    sleep 1
    try += 1
    if try == 7
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE REMOVING STALE USER REQUESTS #{now.to_i} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    retry
  rescue SQLite3::Exception => e
    IPDConfig::DB_HANDLE.rollback
    IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE REMOVING STALE USER REQUESTS #{now.to_i} / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  IPDConfig::DB_HANDLE.commit
end

##############################
job 'message.remove_old' do
  now = Time.now
  try = 0
  begin
    IPDConfig::DB_HANDLE.transaction if try == 0
    result = IPDConfig::DB_HANDLE.execute("SELECT * FROM message WHERE time_created < ?", [now.to_i - IPDConfig::MSG_SHOW_SPAN])
    if result.any?
      IPDConfig::DB_HANDLE.execute("DELETE FROM message WHERE time_created < ?", [now.to_i - IPDConfig::MSG_SHOW_SPAN])
      IPDConfig::LOG_HANDLE.info("REMOVE OLD MESSAGES #{result.size}")
    end
  rescue SQLite3::BusyException => e
    sleep 1
    try += 1
    if try == 7
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE REMOVING OLD MESSAGES #{now.to_i} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    retry
  rescue SQLite3::Exception => e
    IPDConfig::DB_HANDLE.rollback
    IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE REMOVING OLD MESSAGES #{now.to_i} } / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  IPDConfig::DB_HANDLE.commit
end

##############################
job 'picture.report_new' do
  now = Time.now
  result = IPDConfig::DB_HANDLE.execute("SELECT p.filename, p.path, p.time_sent, p.precursor, p.successor, u.nick, d.alias FROM picture p JOIN user u ON p.id_user = u.id JOIN dump d ON p.id_dump = d.id WHERE p.time_sent >= ? ORDER BY p.id asc", [now.to_i - IPDConfig::REPORT_NEW_TIMER])
  if result.any?
    enqueue("email.send", :to => IPDConfig::EMAIL_OPERATOR, :template => :report_new_pictures, :pictures => result, :now => now.to_i, :subject => "New pictures (#{result.size})")
  end
end

##############################
job 'picture.quantize' do |args|
  picture = IPDPicture.load(args["filename"])
  raise PictureMissing unless picture
  cc = picture.quantize
  cc_hex = []
  cc.each do |color|
    cc_hex << sprintf("%02X", color[0]) + sprintf("%02X", color[1]) + sprintf("%02X", color[2])
  end
  try = 0
  begin
    IPDConfig::DB_HANDLE.transaction if try == 0
    IPDConfig::DB_HANDLE.execute("INSERT INTO picture_common_color (id_picture, color) VALUES (?, ?)", [picture.id, cc_hex.join(",")])
  rescue SQLite3::BusyException => e
    sleep 1
    try += 1
    if try == 7
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE SAVING COMMON COLORS ID #{picture.id} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    retry
  rescue SQLite3::Exception => e
    IPDConfig::DB_HANDLE.rollback
    IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE SAVING COMMON COLORS #{picture.id} / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  IPDConfig::DB_HANDLE.commit
end
