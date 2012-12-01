#!/usr/bin/ruby -w

require "sinatra"
require "json"
require "sqlite3"
require '/home/schommer/dev/indypicdump/ipdconfig'
require '/home/schommer/dev/indypicdump/ipdpicture'

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
  IPDPicture.last_random_id = rnd_picture[0][0]
  tt = Time.at(rnd_picture[0][2])
  ts = Time.at(rnd_picture[0][3])
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
