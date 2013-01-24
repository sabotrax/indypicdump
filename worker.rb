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
include Stalker

##############################
job 'email.send' do |args|
  class Env
    attr_accessor :from, :nick, :code, :order, :message, :path, :filename, :dump, :address, :user, :email, :picture_counter
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
  begin
    IPDConfig::DB_HANDLE.transaction
    result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user_request WHERE time_created < ?", [now.to_i - IPDConfig::REQUEST_ACCEPT_SPAN])
    if result.any?
      IPDConfig::DB_HANDLE.execute("DELETE FROM user_request WHERE time_created < ?", [now.to_i - IPDConfig::REQUEST_ACCEPT_SPAN])
      IPDConfig::LOG_HANDLE.info("REMOVED STALE USER REQUESTS #{result.size}")
    end
  rescue SQLite3::Exception => e
    IPDConfig::DB_HANDLE.rollback
    IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE REMOVING STALE USER REQUESTS #{now.to_i}")
    raise
  end
  IPDConfig::DB_HANDLE.commit
end

##############################
job 'message.remove_old' do
  now = Time.now
  begin
    IPDConfig::DB_HANDLE.transaction
    result = IPDConfig::DB_HANDLE.execute("SELECT * FROM message WHERE time_created < ?", [now.to_i - IPDConfig::MSG_SHOW_SPAN])
    if result.any?
      IPDConfig::DB_HANDLE.execute("DELETE FROM message WHERE time_created < ?", [now.to_i - IPDConfig::MSG_SHOW_SPAN])
      IPDConfig::LOG_HANDLE.info("REMOVED OLD MESSAGES #{result.size}")
    end
  rescue SQLite3::Exception => e
    IPDConfig::DB_HANDLE.rollback
    IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE REMOVING OLD MESSAGES #{now.to_i}")
    raise
  end
  IPDConfig::DB_HANDLE.commit
end
