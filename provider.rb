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
require 'ipdconfig'
require 'ipdpicture'
require 'ipdmessage'
require 'ipduser'

log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
log.level = IPDConfig::LOG_LEVEL

##############################
helpers do
  def protected!
    unless authorized?
      response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
      throw(:halt, [401, "Not authorized\n"])
    end
  end

  def authorized?
    @auth ||=  Rack::Auth::Basic::Request.new(request.env)
    @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [IPDConfig::HTTP_AUTH_USER, IPDConfig::HTTP_AUTH_PASS]
  end
end

##############################
# PRODUCTION
#get '/picture/random' do
# DEVELOPMENT
get '/ipd/picture/random' do
  random_id = IPDPicture.get_smart_random_id(request)
  rnd_picture = IPDConfig::DB_HANDLE.execute("SELECT p.id, p.filename, p.time_taken, p.time_send, u.nick FROM picture p INNER JOIN user u ON p.id_user = u.id ORDER BY p.id ASC LIMIT ?, 1", [random_id])
  headers( "Access-Control-Allow-Origin" => "*" )
  # CAUTION
  # this is a workaround for a time zone problem with "time_taken"
  time_taken = rnd_picture[0][2]
  time_send = rnd_picture[0][3]
  if time_taken > time_send
    time_taken -= 3600
    log.warn("TIME_TAKEN > TIME_SEND WARNING ID #{rnd_picture[0][0]}")
  end
  tt = Time.at(time_taken)
  ts = Time.at(time_send)
  {
    filename: rnd_picture[0][1],
    time_taken: tt.strftime("%e.%m.%Y %H:%M"),
    time_send: ts.strftime("%e.%m.%Y %H:%M"),
    nick: rnd_picture[0][4],
  }.to_json
end

##############################
# this is ugly
# TODO
# - return json, not text
# - reinitialize random pool
# PRODUCTION
#get '/picture/delete' do
# DEVELOPMENT
get '/ipd/picture/delete' do
  protected!
  # check params
  if params.has_key?("f")
    filename = params["f"]
    return "FILENAME ERROR" if filename !~ /^\d+\.(\d+\.)?[A-Za-z]{1,4}$/
  else
    return "PARAMETER ERROR"
  end
  # check if picture exists
  result = []
  result = IPDConfig::DB_HANDLE.execute("SELECT id FROM picture WHERE filename = ?", [filename])
  return "FILE NOT FOUND ERROR" if result.empty?
  # delete
  # TODO
  # what's a delete's return val?
  IPDConfig::DB_HANDLE.execute("DELETE FROM picture WHERE id = ?", [result[0][0]])
  # TODO
  # what if picture is served at this moment? retry?
  begin
    File.unlink(IPDConfig::PIC_DIR + "/" + filename)
  rescue Exception => e
    log.fatal("FILE DELETE ERROR #{filename} / #{e.message} / #{e.backtrace.shift}")
  end
  log.info("DELETE PICTURE #{filename} / #{request.ip} / #{request.user_agent}")
  return "DONE"
end

##############################
get '/user/show/:id_user' do
  @user = IPDUser::load_by_id(params[:id_user])
  posts = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM picture WHERE id_user = ?", [params[:id_user]])
  @user.posts = posts[0][0]
  messages = IPDConfig::DB_HANDLE.execute("SELECT * FROM message WHERE id_user = ? AND time_created >= ? ORDER BY time_created DESC", [params[:id_user], Time.now.to_i - IPDConfig::MSG_SHOWN_SPAN])
  @msgs = []
  messages.each do |row|
    @msg = IPDMessage.new
    @msg.id = row[0]
    @msg.message_id = row[1]
    @msg.message_text = IPDConfig::MSG[row[1]]
    @msg.time_created = row[2]
    @msg.id_user = params[:id_user]
    @msgs.push(@msg)
  end
  slim :user, :pretty => true
end
