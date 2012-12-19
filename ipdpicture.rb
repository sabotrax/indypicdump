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
require 'logger'

class IPDPicture
  @log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
  @log.level = IPDConfig::LOG_LEVEL

  @random_pool = {}
  @clients = {}

  ##############################
  def self.get_random_id(request)
    require "random/online"

    id_dump = IPDDump.dump[request.dump]
    @random_pool[id_dump] = [] unless @random_pool.has_key?(id_dump)
    if @random_pool[id_dump].empty?
      # TODO
      # better have real IPDDump objects -> can log dump alias
      @log.info("RANDOM POOL EMPTY DUMP #{id_dump}")
      # TODO
      # catch empty result error
      result = []
      result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM \"#{id_dump}\"")

      randnum = []
      begin
	generator = RealRand::RandomOrg.new
	# TODO
	# - check if result[0][0] - 1 is member of random array
	# as in core rand(max) -> max is never reached
	randnum = generator.randnum(IPDConfig::GEN_RANDOM_IDS, 0, result[0][0] - 1)
      # TODO
      # retry? (The Ruby Programming Language, 162)
      rescue Exception => e
	@log.error("RANDOM NUMBER FETCH ERROR #{e}")
	@log.info("USING RANDOM NUMBER FALLBACK GENERATOR")
	(1..IPDConfig::GEN_RANDOM_IDS).each { randnum.push(rand(result[0][0])) }
      end
      
      @random_pool[id_dump] = randnum
    end
    @random_pool[id_dump].shift
  end

  ##############################
  def self.get_weighted_random_id(request)
    require "random/online"
    require "ipdtest"

    id_dump = IPDDump.dump[request.dump]
    @random_pool[id_dump] = [] unless @random_pool.has_key?(id_dump)
    if @random_pool[id_dump].empty?
      # TODO
      # better have real IPDDump objects -> can log dump alias
      @log.info("RANDOM POOL EMPTY DUMP #{id_dump}")
      # TODO
      # catch empty result error
      result = []
      result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM \"#{id_dump}\"")

      randnum = []
      begin
	generator = RealRand::RandomOrg.new
	# TODO
	# - check if result[0][0] - 1 is member of random array
	# as in core rand(max) -> max is never reached
	randnum = generator.randnum(IPDConfig::GEN_RANDOM_IDS, 0, result[0][0] - 1)
      # TODO
      # retry? (The Ruby Programming Language, 162)
      rescue Exception => e
	@log.error("RANDOM NUMBER FETCH ERROR #{e}")
	@log.info("USING RANDOM NUMBER FALLBACK GENERATOR")
	(1..IPDConfig::GEN_RANDOM_IDS).each { randnum.push(rand(result[0][0])) }
      end
      
      #puts IPDTest.random_distribution(1000, randnum)

      # show newer pics more often
      span = Time.now.to_i - IPDConfig::PICTURE_DISPLAY_MOD_SPAN
      # get new pictures
      result = IPDConfig::DB_HANDLE.execute("SELECT (SELECT COUNT(0) - 1 FROM \"#{id_dump}\" p1 WHERE p1.id <= p2.id) as 'rownum', filename FROM \"#{id_dump}\" p2 WHERE time_send > ?", [span])
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
    id_dump = IPDDump.dump[request.dump]

    # remove old clients
    now = Time.now.to_i
    if @clients.has_key?(key) and @clients[key].has_key?(id_dump)
      # TODO
      # log timeouts w client data from request
      if now - @clients[key][id_dump][:time_created] > IPDConfig::CLIENT_TIMEOUT
	@clients.delete(key)
      end
    end

    # - an array of [some_id, other_id, third_id,] could get new ids array.length times
    # that are already members
    # we then clear the array
    begin
      i = 0

      # find non-sequential id
      while true do
	#random_id = self.get_random_id(request)
	random_id = self.get_weighted_random_id(request)
	if @clients.has_key?(key) and @clients[key].has_key?(id_dump)
	  if @clients[key][id_dump][:ids].include?(random_id)
	    if i == IPDConfig::NOSHOW_LAST_IDS - 1
	      raise
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
    rescue
      @log.warn("BAD LUCK RANDOM ID WARNING DUMP #{id_dump}")
      @clients[key][id_dump][:ids] = []
      retry
    end

    return random_id
  end

  attr_accessor :filename, :time_taken, :time_send, :id_user, :original_hash, :id_dump

  def initialize
    @filename = ""
    @time_taken = 0
    @time_send = 0
    @id_user = 0
    @original_hash = ""
    @id_dump = 0
  end
end
