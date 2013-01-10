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
Thread.abort_on_exception = true
Thread.new do
  class Env
    attr_accessor :pics
  end
  env = Env.new
  while true do
    now_t1 = Time.now
    sleep IPDConfig::REPORT_NEW_TIMER
    result = IPDConfig::DB_HANDLE.execute("SELECT p.filename, p.path, u.nick, d.alias FROM picture p JOIN user u ON p.id_user = u.id JOIN dump d ON p.id_dump = d.id WHERE p.time_sent >= ? ORDER BY p.id asc", [now_t1.to_i])
    if result.any?
      env.pics = result
      t = Slim::Template.new(IPDConfig::PATH + "/templates/mail_new_pictures.slim", :pretty => IPDConfig::RENDER_PRETTY)
      b = t.render(env)
      mail = Mail.new do
	from IPDConfig::EMAIL_SELF
	to IPDConfig::EMAIL_OPERATOR
	subject "new pictures (#{result.size})"
	html_part do
	  content_type "text/html; charset=UTF-8"
	  body b
	end
      end
      mail.delivery_method :sendmail
      mail.deliver
    end
  end
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
      IPDConfig::LOG_HANDLE.info("REMOVED STALE CLIENTS #{s1 - IPDPicture.clients.size}")
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
# this is ugly
# TODO
# - return json, not text
get '/picture/delete/:filename' do
  protected!
  # check params
  if params.has_key?("filename")
    filename = params[:filename]
    return "FILENAME ERROR" if filename !~ /^\d+\.(\d+\.)?[A-Za-z]{3,4}$/
  else
    return "PARAMETER ERROR"
  end
  # check if picture exists
  result = []
  result = IPDConfig::DB_HANDLE.execute("SELECT id, path FROM picture WHERE filename = ?", [filename])
  return "FILE NOT FOUND ERROR" if result.empty?
  id = result[0][0]
  path = result[0][1]
  # delete
  # TODO
  # what's a delete's return val?
  IPDConfig::DB_HANDLE.execute("DELETE FROM picture WHERE id = ?", [id])
  # TODO
  # what if picture is served at this moment? retry?
  begin
    File.unlink(IPDConfig::PIC_DIR + "/" + path + "/" + filename)
  rescue Exception => e
    IPDConfig::LOG_HANDLE.fatal("FILE DELETE ERROR #{filename} / #{e.message} / #{e.backtrace.shift}")
  end
  IPDConfig::LOG_HANDLE.info("DELETE PICTURE #{filename} / #{request.ip} / #{request.user_agent}")
  return "DONE"
end

##############################
get '/picture/show/user/:nick' do
  # get here from /pic/show/user/:nick/random (and others)
  if request.has_dump? and IPDUser.is_user?(params[:nick])
    id_dump = request.dump
    begin
      i = 0
      while true
	random_id = IPDPicture.get_smart_random_id(request)
	rnd_picture = IPDConfig::DB_HANDLE.execute("SELECT p.id, p.filename, p.time_taken, p.time_sent, p.id_user, p.path, u.nick, u.accept_external_messages FROM \"#{id_dump}\" p INNER JOIN user u ON p.id_user = u.id ORDER BY p.id ASC LIMIT ?, 1", [random_id])
	err = false
	if rnd_picture.empty?
	  err = true
	  IPDConfig::LOG_HANDLE.warn("PICTURE MISSING WARNING OFFSET #{random_id} DUMP #{id_dump}")
	elsif !File.exists?(IPDConfig::PIC_DIR + "/" + rnd_picture[0][5] + "/" + rnd_picture[0][1])
	  err = true
	  IPDConfig::LOG_HANDLE.error("PICTURE MISSING ERROR #{rnd_picture[0][5]}/#{rnd_picture[0][1]}")
	end
	if err
	  i += 1
	  raise if i == 5
	  next
	end
	break
      end
    # TODO
    # use own error class
    # this is catch all :/
    rescue Exception => e
      IPDConfig::LOG_HANDLE.fatal("PICTURE MISSING ERROR DUMP #{id_dump}")
      @msg = "No pictures."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
    @pic = IPDPicture.new
    @pic.id = rnd_picture[0][0]
    @pic.filename = rnd_picture[0][1]
    @pic.time_taken = rnd_picture[0][2]
    @pic.time_sent = rnd_picture[0][3]
    @user = IPDUser.new
    @user.id = rnd_picture[0][4]
    @user.nick = rnd_picture[0][6]
    @user.accept_external_messages = rnd_picture[0][7]
    @pic.path = rnd_picture[0][5]

    slim :dump, :pretty => IPDConfig::RENDER_PRETTY, :layout => false
  else
    # TODO
    # better: Pool not found. You might create it? w link
    raise Sinatra::NotFound
  end
end

##############################
get '/picture/contact/:nick/about/:filename' do
  @user = IPDUser::load_by_nick(params[:nick])
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
  @picture = IPDPicture::load_by_filename(params[:filename])
  slim :contact, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
post '/picture/contact/:nick/about/:filename' do
  @user = IPDUser::load_by_nick(params[:nick])
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
  @picture = IPDPicture::load_by_filename(params[:filename])
  redirect "/picture/contact/#{@user.nick.dash}/about/#{@picture.filename}" if params[:message].nil? or params[:message].empty? or params[:message] =~ /\A\s+\z/ or !recaptcha_valid?
  message = params[:message].gsub(/\r/, "").strip
  regex = %r{([a-z0-9!#$\%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$\%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|asia|jobs|museum))\b}i
  message.gsub!(regex, '<a href="mailto:\1?subject=Your fan mail">\1</a>')
  Stalker.enqueue("email.send", :to => @user.email.first, :messages_message => true, :message => message, :nick => @user.nick, :path => @picture.path, :filename => @picture.filename, :subject => "A message from a fan or not")
  @msg = "OK."
  # TODO
  # remember source (md or ud) for proper redirection
  #response.headers['Refresh'] = '5;url=http://some.com'
  slim :notice, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
get '/user/show/:nick' do
  @user = IPDUser::load_by_nick(params[:nick])
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
get '/dump/create/?' do
  @msg = ""
  slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
end

##############################
post '/dump/create/?' do
  protected!
  # CAUTION
  # "downcase" only works in the ASCII region
  dump_alias = params[:dump].strip.downcase
  dump_alias.tr!(" ", "-")
  redirect '/dump/create' if dump_alias.nil? or dump_alias.empty? or dump_alias !~ /^[a-zA-Z0-9][a-zA-Z0-9\-]*(?<!-)$/ or !recaptcha_valid?
  result = IPDConfig::DB_HANDLE.execute("SELECT * FROM dump WHERE alias = ?", [dump_alias])
  if result.any?
    @msg = "Sry, this dump already exists."
    halt slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
  end
  reserved = File.readlines(IPDConfig::RESERVED)
  # \n chomp hack
  if reserved.include?(dump_alias.undash + "\n")
    @msg = "Sry, reserved word."
    halt slim :dump_create, :pretty => IPDConfig::RENDER_PRETTY
  end
  dump = IPDDump.new
  dump.alias = dump_alias
  dump.save
  IPDDump.reload_dump_map
  IPDConfig::LOG_HANDLE.info("NEW DUMP #{dump.alias} / #{request.ip} / #{request.user_agent}")
  @msg = "OK, now add pictures to <a href=\"/#{dump.alias}\">http://indypicdump/#{dump.alias}</a>."
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
not_found do
  @msg = "Not found."
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
	rnd_picture = IPDConfig::DB_HANDLE.execute("SELECT p.id, p.filename, p.time_taken, p.time_sent, p.id_user, p.path, u.nick, u.accept_external_messages FROM \"#{id_dump}\" p INNER JOIN user u ON p.id_user = u.id ORDER BY p.id ASC LIMIT ?, 1", [random_id])
	err = false
	if rnd_picture.empty?
	  err = true
	  IPDConfig::LOG_HANDLE.warn("PICTURE MISSING WARNING OFFSET #{random_id} DUMP #{id_dump}")
	elsif !File.exists?(IPDConfig::PIC_DIR + "/" + rnd_picture[0][5] + "/" + rnd_picture[0][1])
	  err = true
	  IPDConfig::LOG_HANDLE.error("PICTURE MISSING ERROR #{rnd_picture[0][5]}/#{rnd_picture[0][1]}")
	end
	if err
	  i += 1
	  raise if i == 5
	  next
	end
	break
      end
    # TODO
    # use own error class
    # this is catch all :/
    rescue Exception => e
      IPDConfig::LOG_HANDLE.fatal("PICTURE MISSING ERROR DUMP #{id_dump}")
      @msg = "No pictures."
      halt slim :notice, :pretty => IPDConfig::RENDER_PRETTY
    end
    @pic = IPDPicture.new
    @pic.id = rnd_picture[0][0]
    @pic.filename = rnd_picture[0][1]
    @pic.time_taken = rnd_picture[0][2]
    @pic.time_sent = rnd_picture[0][3]
    @user = IPDUser.new
    @user.id = rnd_picture[0][4]
    @user.nick = rnd_picture[0][6]
    @user.accept_external_messages = rnd_picture[0][7]
    @pic.path = rnd_picture[0][5]

    slim :dump, :pretty => IPDConfig::RENDER_PRETTY, :layout => false
  else
    # TODO
    # better: Pool not found. You might create it? w link
    raise Sinatra::NotFound
  end
end
