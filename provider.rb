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

require 'sinatra'
require 'json'
require 'sqlite3'
require 'slim'
require 'rack/recaptcha'
require 'mail'
require 'stalker'
require 'ipdconfig'
require 'ipdpicture'
require 'ipdmessage'
require 'ipduser'
require 'ipddump'
require 'ipdhelper'
require 'ipderror'
require 'ipdrequest'

set :environment, IPDConfig::ENVIRONMENT
use Rack::Recaptcha, :public_key => IPDConfig::RECAPTCHA_PUB_KEY, :private_key => IPDConfig::RECAPTCHA_PRIV_KEY
helpers Rack::Recaptcha::Helpers
Rack::Recaptcha.test_mode! if IPDConfig::ENVIRONMENT == :development
$stdout.sync = true

##############################
configure do
  IPDDump.load_dump_map
end

##############################
Thread.new do
  while true do
    sleep IPDConfig::CLIENT_TIMEOUT * 3
    now_t2 = Time.now
    s1 = IPDPicture.clients.size
    IPDPicture.clients.each_key do |client|
      IPDPicture.clients[client].each_key do |dump|
	if now_t2.to_i - IPDPicture.clients[client][dump][:time_created] > IPDConfig::CLIENT_TIMEOUT
	  IPDPicture.clients[client].delete(dump)
	end
      end
      IPDPicture.clients.delete(client) if IPDPicture.clients[client].size == 0
    end
    if s1 != IPDPicture.clients.size
      # TODO
      # better lock clients hash through this operations
      # clients could have been changed somewhere else (by adding new clients)
      IPDConfig::LOG_HANDLE.info("REMOVE STALE CLIENTS #{s1 - IPDPicture.clients.size}/#{s1}")
    end
  end
end

##############################
helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      @msg = "Not authorized."
      halt [401, slim(:notice, :pretty => IPDConfig::RENDER_PRETTY)]
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [IPDConfig::HTTP_AUTH_USER, IPDConfig::HTTP_AUTH_PASS]
  end
end

##############################
get '/picture/delete/:filename' do
  protected!
  # check params
  unless params[:filename] =~ /^\d+\.(\d+\.)?[a-z]{3,4}$/i
    @msg = "Something went wrong:<br /><p>Argument error.</p>"
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  # check if picture exists
  result = IPDConfig::DB_HANDLE.execute("SELECT id FROM picture WHERE filename = ?", [params[:filename]])
  if result.empty?
    @msg = "Something went wrong:<br /><p>Picture is missing.</p>"
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  begin
    IPDPicture.delete(result[0][0])
  rescue Exception => e
      @msg = "Something went wrong:<br /><p>#{e.message}</p>"
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  IPDConfig::LOG_HANDLE.info("DELETE PICTURE ID #{result[0][0]} / #{request.ip} / #{request.user_agent}")
  @msg = "Picture deleted."
  halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/picture/show/user/:nick' do
  # get here from /pic/show/user/:nick/random (and others)
  if request.has_dump? and IPDUser.exists?(params[:nick])
    id_dump = request.dump
    begin
      i = 0
      while true
	random_id = IPDPicture.get_smart_random_id(request)
	rnd_picture = IPDConfig::DB_HANDLE.execute("SELECT p.id, p.filename, p.time_taken, p.time_sent, p.id_user, p.path, p.precursor, p.successor, u.nick, u.accept_external_messages FROM picture p JOIN user u ON p.id_user = u.id WHERE p.id = ?", [random_id])
	err = false
	if rnd_picture.empty?
	  err = true
	  IPDConfig::LOG_HANDLE.warn("PICTURE MISSING WARNING ID #{random_id} DUMP #{id_dump}")
	elsif !File.exists?(IPDConfig::PICTURE_DIR + "/" + rnd_picture[0][5] + "/" + rnd_picture[0][1])
	  err = true
	  IPDConfig::LOG_HANDLE.error("PICTURE MISSING ERROR #{rnd_picture[0][5]}/#{rnd_picture[0][1]}")
	end
	if err
	  i += 1
	  raise PictureMissing, "PICTURE MISSING ERROR DUMP #{id_dump}" if i == 5
	  next
	end
	break
      end
    rescue DumpEmpty, PictureMissing => e
      IPDConfig::LOG_HANDLE.fatal(e.message) if e.class.name == "PictureMissing"
      @msg = "No pictures."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
    @picture = IPDPicture.new
    @picture.id = rnd_picture[0][0]
    @picture.filename = rnd_picture[0][1]
    @picture.time_taken = rnd_picture[0][2]
    @picture.time_sent = rnd_picture[0][3]
    @user = IPDUser.new
    @user.id = rnd_picture[0][4]
    @user.nick = rnd_picture[0][8]
    @user.accept_external_messages = rnd_picture[0][9]
    @picture.path = rnd_picture[0][5]
    @picture.dump = "ud"
    @picture.precursor = rnd_picture[0][6]
    @picture.successor = rnd_picture[0][7]

    slim :dump, :pretty => IPDConfig::RENDER_PRETTY, :layout => false
  else
    raise Sinatra::NotFound
  end
end

##############################
get '/picture/contact/:nick/about/:filename/in/:dump' do
  @user = IPDUser.load(params[:nick])
  unless @user
    @msg = "No such user."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  unless @user.accept_external_messages?
    @msg = "User no want contact with other species."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  unless IPDPicture.exists?(params[:filename])
    @msg = "Picture is not existing."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  unless @user.owns_picture?(params[:filename])
    @msg = "User is not owning picture."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  @picture = IPDPicture.load(params[:filename])
  unless params[:dump] == "ud"
    unless IPDDump.exists?(params[:dump])
      @msg = "Dump does not exists."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
    unless @picture.dump == params[:dump].dash
      @msg = "Picture is not member of dump."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
  else
    @picture.dump = "ud"
  end
  @msg = ""
  @message = ""
  slim :contact, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
post '/picture/contact/:nick/about/:filename/in/:dump' do
  @user = IPDUser.load(params[:nick])
  unless @user
    @msg = "No such user."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  unless @user.accept_external_messages?
    @msg = "User no want contact with other species."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  unless IPDPicture.exists?(params[:filename])
    @msg = "Picture is not existing."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  unless @user.owns_picture?(params[:filename])
    @msg = "User is not owning picture."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  @picture = IPDPicture.load(params[:filename])
  unless params[:dump] == "ud"
    unless IPDDump.exists?(params[:dump])
      @msg = "Dump does not exists."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
    unless @picture.dump == params[:dump].dash
      @msg = "Picture is not member of dump."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
  end
  if params[:message].nil? or params[:message].empty? or params[:message] =~ /\A\s+\z/ or !recaptcha_valid?
    @msg = "Try again."
    @message = params[:message]
    halt slim :contact, :pretty => IPDConfig::RENDER_PRETTY
  end
  message = params[:message].gsub(/\r/, "").strip
  message.gsub!(/(#{IPDConfig::REGEX_EMAIL})/i, '<a href="mailto:\1?subject=Your fan mail">\1</a>')
  Stalker.enqueue("email.send", :to => @user.email.first, :template => :messages_message, :message => message, :nick => @user.nick, :path => @picture.path, :filename => @picture.filename, :subject => "A message from a fan or not")
  @msg = "Message sent. You will be redirected."
  if params[:dump] == "ud"
    url = "/picture/show/user/#{@user.nick.dash}"
  else
    url = "/#{params[:dump]}"
  end
  response.headers['Refresh'] = "5;url=#{url}"
  slim :notice, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/user/show/:nick' do
  @user = IPDUser.load(params[:nick])
  unless @user
    @msg = "No such user."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  posts = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM picture WHERE id_user = ?", [@user.id])
  @user.posts = posts[0][0]
  messages = IPDConfig::DB_HANDLE.execute("SELECT * FROM message WHERE id_user = ? AND time_created >= ? ORDER BY time_created DESC", [@user.id, Time.now.to_i - IPDConfig::MSG_SHOW_SPAN])
  @msgs = []
  messages.each do |row|
    @msg = IPDMessage.new
    @msg.id = row[0]
    @msg.message_id = row[1]
    @msg.message_text = IPDConfig::MSG[row[1]]
    @msg.time_created = row[2]
    @msg.id_user = @user.id
    @msgs.push(@msg)
  end
  slim :user, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/dump/show/:dump' do
  @dump = IPDDump.load(params[:dump])
  unless @dump
    @msg = "No such dump."
    halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
  end
  result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM \"#{@dump.id}\"")
  @picture_counter = result[0][0]
  result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM mapping_dump_user WHERE id_dump = ?", [@dump.id])
  @user_counter = result[0][0]
  result = IPDConfig::DB_HANDLE.execute("SELECT id_user, count(1) posts FROM \"#{@dump.id}\" GROUP BY id_user ORDER BY posts DESC, id_user ASC LIMIT 10")
  @users = []
  result.each do |row|
    user = IPDUser.load(row[0])
    unless user
      IPDConfig::LOG_HANDLE.error("USER MISSING ERROR ID #{row[0]} / #{caller[0]}")
      next
    end
    user.posts = row[1]
    @users.push(user)
  end
  # add titles
  (0..@users.length - 1).each do |i|
    if IPDConfig::DUMP_HONOR_TITLES[i]
      if IPDConfig::DUMP_HONOR_TITLES[i] =~ /%i(\"[^"]+\")/
	nick = @users[i].nick.split(" ")
	nick.insert(1, $1)
	nick_w_title = nick.join(" ")
      else
	nick_w_title = IPDConfig::DUMP_HONOR_TITLES[i].sub(/%n/, @users[i].nick)
	nick_w_title = nick_w_title.sub(/%d/, @dump.alias.undash)
      end
      @users[i].nick_w_title = nick_w_title 
    else
      break
    end
  end
  slim :dump_show, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/dump/create/?' do
  @msg = ""
  slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
post '/dump/create/?' do
  # CAUTION
  # "downcase" only works in the ASCII region
  dump_alias = params[:dump].strip.downcase
  dump_alias.tr!(" ", "-")
  redirect '/dump/create' if dump_alias.nil? or dump_alias.empty? or dump_alias !~ /^[a-zA-Z0-9][a-zA-Z0-9\-]*(?<!-)$/ or !recaptcha_valid?
  if dump_alias.length > 64
    @msg = "Keep dump names shorter than 64 characters."
    halt slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
  end
  result = IPDConfig::DB_HANDLE.execute("SELECT * FROM dump WHERE alias = ?", [dump_alias])
  if result.any?
    @msg = "Sry, this dump already exists."
    halt slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
  end
  reserved = File.readlines(IPDConfig::RESERVED_DUMPS)
  # \n chomp hack
  if reserved.include?(dump_alias.undash + "\n")
    @msg = "Sry, reserved word."
    halt slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
  end
  address = params[:email].strip.downcase
  user = IPDUser.load(address)
  # create dump and add known users to it
  if user
    dump = IPDDump.new
    dump.alias = dump_alias
    dump.save
    IPDConfig::LOG_HANDLE.info("NEW DUMP #{dump.alias} / #{request.ip} / #{request.user_agent}")
    dump.add_user(user.id)
    Stalker.enqueue("email.send", :to => address, :template => :create_dump_notice_creator, :nick => user.nick, :dump => dump.alias.undash, :subject => "A new place to store pictures")
    IPDConfig::LOG_HANDLE.info("ADD USER #{user.nick} TO DUMP #{dump.alias}")
    IPDDump.reload_dump_map
    @msg = "OK, now add pictures to <a href=\"/#{dump.alias}\">http://indypicdump/#{dump.alias}</a>."
  # invite new users
  else
    unless address =~ /^#{IPDConfig::REGEX_EMAIL}$/i
      @msg = "Invalid email address."
      halt slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
    end
    request = IPDRequest.new
    request.action = ["create dump", dump_alias, address].join(",")
    request.save
    Stalker.enqueue("email.send", :to => address, :template => :new_user_request_code, :code => request.code, :subject => "indypicdump - collect and share")
    @msg = "Hello new user,<br><p>we just sent an invitation to the address you provided. Please check your email.</p>"
  end
  slim :notice, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/admin/pool/show' do
  IPDPicture.random_pool.to_json
end

##############################
get '/admin/pool/empty' do
  protected!
  IPDPicture.random_pool = {}
  IPDConfig::LOG_HANDLE.info("POOL EMPTIED #{request.ip} / #{request.user_agent}")
  IPDPicture.random_pool.to_json
end

##############################
get '/' do
  slim :landing, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/usage.html' do
  protected!
  slim :usage, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/about.html' do
  @counter = IPDPicture.count_pictures
  slim :about, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
not_found do
  @msg = "Not found."
  slim :notice, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
error do
  @msg =  "<p>\"I have not failed. I've just found 10,000 ways that won't work.\" -- Thomas A. Edison</p><p>Having read this quote you will probably be lenient with us because this is but more than an error page.</p>"
  slim :notice, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/*' do
  if request.has_dump? and IPDDump.dump.has_key?(request.dump)
    id_dump = IPDDump.dump[request.dump]
    begin
      i = 0
      while true
	random_id = IPDPicture.get_smart_random_id(request)
	rnd_picture = IPDConfig::DB_HANDLE.execute("SELECT p.id, p.filename, p.time_taken, p.time_sent, p.id_user, p.path, p.precursor, p.successor, u.nick, u.accept_external_messages, d.alias FROM picture p JOIN user u ON p.id_user = u.id JOIN dump d ON p.id_dump = d.id WHERE p.id = ?", [random_id])
	err = false
	if rnd_picture.empty?
	  err = true
	  IPDConfig::LOG_HANDLE.warn("PICTURE MISSING WARNING ID #{random_id} DUMP #{id_dump}")
	elsif !File.exists?(IPDConfig::PICTURE_DIR + "/" + rnd_picture[0][5] + "/" + rnd_picture[0][1])
	  err = true
	  IPDConfig::LOG_HANDLE.error("PICTURE MISSING ERROR #{rnd_picture[0][5]}/#{rnd_picture[0][1]}")
	end
	if err
	  i += 1
	  raise PictureMissing, "PICTURE MISSING ERROR DUMP #{id_dump}" if i == 5
	  next
	end
	break
      end
    rescue DumpEmpty, PictureMissing => e
      IPDConfig::LOG_HANDLE.fatal(e.message) if e.class.name == "PictureMissing"
      @msg = "No pictures."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
    @picture = IPDPicture.new
    @picture.id = rnd_picture[0][0]
    @picture.filename = rnd_picture[0][1]
    @picture.time_taken = rnd_picture[0][2]
    @picture.time_sent = rnd_picture[0][3]
    @user = IPDUser.new
    @user.id = rnd_picture[0][4]
    @user.nick = rnd_picture[0][8]
    @user.accept_external_messages = rnd_picture[0][9]
    @picture.path = rnd_picture[0][5]
    @picture.dump = rnd_picture[0][10]
    @picture.precursor = rnd_picture[0][6]
    @picture.successor = rnd_picture[0][7]

    slim :dump, :pretty => IPDConfig::RENDER_PRETTY, :layout => false
  else
    raise Sinatra::NotFound
  end
end
