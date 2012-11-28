#!/usr/bin/ruby -w

require "sinatra"
require "json"
require "sqlite3"
require '/home/schommer/dev/indypicdump/ipdconfig'
require '/home/schommer/dev/indypicdump/ipdpicture'

# setup
db = SQLite3::Database.new IPDConfig::DB

# PRODUCTION
get '/picture/random' do
# DEVELOPMENT
#get '/ipd/picture/random' do
  rnd_picture = db.execute("SELECT p.id, p.filename, p.time_taken, p.time_send, u.nick FROM picture p INNER JOIN user u ON p.id_user = u.id where p.id != ? order by random() limit 1", IPDPicture.last_random_id)
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
