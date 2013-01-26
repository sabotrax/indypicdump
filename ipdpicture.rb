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

require 'sqlite3'
require "random/online"
require 'RMagick'

class IPDPicture
  @random_pool = {}
  @clients = {}

  class << self
    attr_accessor :random_pool
    attr_reader :clients
  end

  ##############################
  def self.get_weighted_random_id(request)
    require "ipdtest"

    id_dump = IPDDump.dump[request.dump] || request.dump
    @random_pool[id_dump] = [] unless @random_pool.has_key?(id_dump)
    if @random_pool[id_dump].empty?
      IPDConfig::LOG_HANDLE.info("RANDOM POOL EMPTY DUMP #{id_dump}")
      result = []
      result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM \"#{id_dump}\"")
      raise DumpEmpty, "DUMP EMPTY DUMP #{id_dump}" if result[0][0] == 0

      randnum = []
      begin
	# one-picture-dumps just aren't random
	if result[0][0] == 1
	  (1..IPDConfig::GEN_RANDOM_IDS).each { randnum.push([0]) }
	else
	  generator = RealRand::RandomOrg.new
	  randnum = generator.randnum(IPDConfig::GEN_RANDOM_IDS, 0, result[0][0] - 1)
	end
      # TODO
      # retry? (The Ruby Programming Language, 162)
      # better use own error class vs. catchall
      rescue Exception => e
	IPDConfig::LOG_HANDLE.error("RANDOM NUMBER FETCH ERROR #{e}")
	IPDConfig::LOG_HANDLE.info("USING FALLBACK RANDOM NUMBER GENERATOR")
	(1..IPDConfig::GEN_RANDOM_IDS).each { randnum.push(rand(result[0][0])) }
      end
      
      #puts IPDTest.random_distribution(1000, randnum)

      # show newer pics more often
      span = Time.now.to_i - IPDConfig::PICTURE_DISPLAY_MOD_SPAN
      # get new pictures
      result = IPDConfig::DB_HANDLE.execute("SELECT (SELECT COUNT(0) - 1 FROM \"#{id_dump}\" p1 WHERE p1.id <= p2.id) as 'rownum', filename FROM \"#{id_dump}\" p2 WHERE time_sent > ?", [span])
      result.each do |row|
	offset = row[0]
	# create random positions for later injection
	weighted = []
	(1..(IPDConfig::GEN_RANDOM_IDS * IPDConfig::PICTURE_DISPLAY_MOD)).each do
	  weighted.push(rand(randnum.length))
	end
	# merge
	weighted.each do |p|
	  randnum.insert(p, offset)
	end
      end
      #puts IPDTest.random_distribution(1000, randnum)

      @random_pool[id_dump] = randnum
    end
    @random_pool[id_dump].shift
  end

  ##############################
  # - generate smart random ids
  # so the last IPDConfig::NOSHOW_LAST_IDS won't be drawn again
  # - this works per client with a IPDConfig::CLIENT_TIMEOUT second timeout 
  # 
  # request = sinatra request object
  def self.get_smart_random_id(request)
    # identify client
    key = Digest::RMD160::hexdigest(request.ip + request.user_agent).to_sym
    # and dump
    # multi or user dump
    id_dump = IPDDump.dump[request.dump] || request.dump

    now = Time.now.to_i
    # update recurring clients
    if @clients.has_key?(key) and @clients[key].has_key?(id_dump)
      @clients[key][id_dump][:time_created] = now
    end
    
    # - an array of [some_id, other_id, third_id,] could get new ids array.length times
    # that are already members
    # we then clear the array
    begin
      i = 0

      # find non-sequential id
      while true do
	random_id = self.get_weighted_random_id(request)
	if @clients.has_key?(key) and @clients[key].has_key?(id_dump)
	  if @clients[key][id_dump][:ids].include?(random_id)
	    if i == IPDConfig::NOSHOW_LAST_IDS - 1
	      raise BadLuck, "BAD LUCK RANDOM ID WARNING DUMP #{id_dump}"
	    else
	      i += 1
	      next
	    end
	  end
	else
	  unless @clients[key].kind_of?(Hash)
	    @clients[key] = {}
	  end
	  unless @clients[key][id_dump].kind_of?(Hash)
	    @clients[key][id_dump] = {
	      :time_created => now,
	      :ids => [],
	    }
	  end
	end
	@clients[key][id_dump][:ids].push(random_id)
	if @clients[key][id_dump][:ids].length > IPDConfig::NOSHOW_LAST_IDS
	  @clients[key][id_dump][:ids].shift
	end
	break
      end
    rescue DumpEmpty => e
      IPDConfig::LOG_HANDLE.info(e.message)
      raise
    rescue BadLuck => e
      IPDConfig::LOG_HANDLE.warn(e.message)
      @clients[key][id_dump][:ids] = []
      retry
    end

    return random_id
  end

  ##############################
  def self.load(p)
    result = []
    picture = nil
    if p.to_s =~ /^[1-9]\d*$/
      result = IPDConfig::DB_HANDLE.execute("SELECT p.*, d.alias FROM picture p JOIN dump d ON p.id_dump = d.id WHERE p.id = ?", [p])
    elsif p =~ /^\d+\.(\d+\.)?[a-z]{3,4}$/i
      result = IPDConfig::DB_HANDLE.execute("SELECT p.*, d.alias FROM picture p JOIN dump d ON p.id_dump = d.id WHERE p.filename = ?", [p])
    end
    if result.any?
      picture = self.new
      picture.id = result[0][0]
      picture.filename = result[0][1]
      picture.time_taken = result[0][2]
      picture.time_sent = result[0][3]
      picture.id_user = result[0][4]
      picture.original_hash = result[0][5]
      picture.id_dump = result[0][6]
      picture.path = result[0][7]
      picture.dump = result[0][8]
    end
    return picture
  end

  ##############################
  def self.exists?(p)
    result = []
    picture_exists = false
    if p =~ /^\d+\.(\d+\.)?[a-z]{3,4}$/i
      result = IPDConfig::DB_HANDLE.execute("SELECT id, path FROM picture WHERE filename = ?", [p])
    end
    if result.any?
      if File.exists?(IPDConfig::PICTURE_DIR + "/" + result[0][1] + "/" + p)
	picture_exists = result[0][0]
      else
	IPDConfig::LOG_HANDLE.error("PICTURE MISSING ERROR #{result[0][1]}/#{p} in #{caller[0]}")
      end
    end
    return picture_exists
  end

  ##############################
  def self.count_pictures
    result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM picture")
    return result[0][0]
  end

  attr_accessor :id, :filename, :time_taken, :time_sent, :id_user, :original_hash, :id_dump, :path, :dump

  ##############################
  def initialize
    @id = 0
    @filename = ""
    @time_taken = 0
    @time_sent = 0
    @id_user = 0
    @original_hash = ""
    @id_dump = 0
    @path = ""
    @dump = ""
  end

  ##############################
  # returns the most common colors of a picture
  # as [[r, g, b], ..]
  def quantize
    image = Magick::ImageList.new(IPDConfig::PICTURE_DIR + "/" + self.path + "/" + self.filename)
    colors = []
    # we're looking for the 7 most common colors
    q = image.quantize(7, Magick::RGBColorspace)
    palette = q.color_histogram.sort {|a, b| b[1] <=> a[1]}
    (0..6).each do |i|
      c = palette[i].to_s.split(',').map {|x| x[/\d+/]}
      c.pop
      c[0], c[1], c[2] = [c[0], c[1], c[2]].map { |s| 
	s = s.to_i
	if s / 255 > 0 # not all ImageMagicks are created equal....
	  s = s / 255
	end
	s
      }
      c = c.slice(0..2)
      colors << c
    end
    return colors
  end

end
