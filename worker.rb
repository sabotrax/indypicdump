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

$:.unshift("#{File.dirname(__FILE__)}/lib")

require 'stalker'
require 'mail'
require 'slim'
require 'ipdconfig'
require 'ipderror'
require 'ipdhelper'
require 'ipdpicture'
require 'ipdrequest'

include Stalker
include IPDConfig

##############################
job 'email.send' do |args|
  class Env
    attr_accessor :from, :nick, :code, :order, :message, :path, :filename, :dump, :address, :user, :email, :picture_counter, :common_color, :pictures, :now, :state, :password
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
  env.state = args["state"]
  env.password = args["password"]
  template_file = TEMPLATE_DIR + "/mail_#{args['template']}.slim"
  template = Slim::Template.new(template_file, :pretty => RENDER_PRETTY)
  body = template.render(env)
  mail = Mail.new do
    from EMAIL_SELF
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
    DB_HANDLE.transaction if try == 0
    result = DB_HANDLE.execute("SELECT * FROM user_request WHERE time_created < ?", [now.to_i - REQUEST_ACCEPT_SPAN])
    if result.any?
      DB_HANDLE.execute("DELETE FROM user_request WHERE time_created < ?", [now.to_i - REQUEST_ACCEPT_SPAN])
      LOG_HANDLE.info("REMOVE STALE USER REQUESTS #{result.size}")
    end
  rescue SQLite3::BusyException => e
    sleep 1
    try += 1
    if try == 7
      DB_HANDLE.rollback
      LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE REMOVING STALE USER REQUESTS #{now.to_i} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    retry
  rescue SQLite3::Exception => e
    DB_HANDLE.rollback
    LOG_HANDLE.fatal("DB ERROR WHILE REMOVING STALE USER REQUESTS #{now.to_i} / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  DB_HANDLE.commit
end

##############################
job 'message.remove_old' do
  now = Time.now
  try = 0
  begin
    DB_HANDLE.transaction if try == 0
    result = DB_HANDLE.execute("SELECT * FROM message WHERE time_created < ?", [now.to_i - MSG_SHOW_SPAN])
    if result.any?
      DB_HANDLE.execute("DELETE FROM message WHERE time_created < ?", [now.to_i - MSG_SHOW_SPAN])
      LOG_HANDLE.info("REMOVE OLD MESSAGES #{result.size}")
    end
  rescue SQLite3::BusyException => e
    sleep 1
    try += 1
    if try == 7
      DB_HANDLE.rollback
      LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE REMOVING OLD MESSAGES #{now.to_i} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    retry
  rescue SQLite3::Exception => e
    DB_HANDLE.rollback
    LOG_HANDLE.fatal("DB ERROR WHILE REMOVING OLD MESSAGES #{now.to_i} } / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  DB_HANDLE.commit
end

##############################
job 'picture.report_new' do
  now = Time.now
  result = DB_HANDLE.execute("SELECT p.filename, p.path, p.time_sent, p.precursor, p.successor, u.nick, d.alias FROM picture p JOIN user u ON p.id_user = u.id JOIN dump d ON p.id_dump = d.id WHERE p.time_sent >= ? ORDER BY p.id asc", [now.to_i - REPORT_NEW_TIMER])
  if result.any?
    enqueue("email.send", :to => EMAIL_OPERATOR, :template => :report_new_pictures, :pictures => result, :now => now.to_i, :subject => "New pictures (#{result.size})")
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
    DB_HANDLE.transaction if try == 0
    DB_HANDLE.execute("INSERT INTO picture_common_color (id_picture, color) VALUES (?, ?)", [picture.id, cc_hex.join(",")])
  rescue SQLite3::BusyException => e
    sleep 1
    try += 1
    if try == 7
      DB_HANDLE.rollback
      LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE SAVING COMMON COLORS ID #{picture.id} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    retry
  rescue SQLite3::Exception => e
    DB_HANDLE.rollback
    LOG_HANDLE.fatal("DB ERROR WHILE SAVING COMMON COLORS #{picture.id} / #{e.message} / #{e.backtrace.shift}")
    raise
  end
  DB_HANDLE.commit
end

##############################
job 'picture.complete_removal' do
  now = Time.now
  result = DB_HANDLE.execute("SELECT action FROM user_request WHERE action LIKE \"remove pictures,complete%\" AND time_created < ?", [now.to_i - PICTURE_REMOVAL_GRACE_SPAN])
  result.each do |row|
    action = row[0].split(",")
    remove_ids = action.slice(3..-1)
    remove_ids.each do |id|
      IPDPicture.delete(id)
    end
    IPDRequest.remove_by_action(row[0])
    request = IPDRequest.new
    request.action = ["remove pictures", "cleared", action[2], remove_ids.size].join(",")
    request.save
  end
end
