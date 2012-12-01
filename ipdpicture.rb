require "sqlite3"
require "logger"
require '/home/schommer/dev/indypicdump/ipdconfig'

class IPDPicture
  @@log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
  @@log.level = IPDConfig::LOG_LEVEL

  @last_random_id = 0
  @random_pool = []
  @@clients = {}

  def self.last_random_id
    @last_random_id
  end

  def self.last_random_id=(id)
    @last_random_id = id
  end

  def self.get_random_id
    require "random/online"

    if @random_pool.empty?
      @@log.info("RANDOM POOL EMPTY")
      # TODO
      # catch empty result error
      result = []
      result = IPDConfig::DB_HANDLE.execute("SELECT count(*) FROM picture")
      #puts "COUNT PICTURES " + result[0][0].to_s

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
	@@log.error("RANDOM NUMBER FETCH ERROR #{e}")
	@@log.info("USING RANDOM NUMBER FALLBACK GENERATOR")
	for i in 1..IPDConfig::GEN_RANDOM_IDS
	  randnum.push(rand(result[0][0]))
	end
      end
      
      @random_pool = randnum
    end
    @random_pool.shift
  end

  ##############################
  # - generate smart random ids
  # so that the last IPDConfig::NOSHOW_IDS won't be drawn again
  # - this works per client with a IPDConfig::CLIENT_TIMEOUT second timeout 
  # 
  # request = sinatra request object
  def self.get_smart_random_id(request)
    # identify client
    key = Digest::RMD160::hexdigest(request.ip + request.user_agent).to_sym

    # remove old clients
    now = Time.now.to_i
    if @@clients.has_key?(key)
      # TODO
      # log timeouts w client data from request
      if now - @@clients[key][:created_time] > IPDConfig::CLIENT_TIMEOUT
	@@clients.delete(key)
      end
    end

    # - an array of [some_id, other_id, third_id,] could get new ids array.length times
    # that are already members
    # we then clear the array
    begin
      i = 0

      # find non-sequential id
      while true do
	random_id = self.get_random_id
	if @@clients.has_key?(key)
	  if @@clients[key][:ids].include?(random_id)
	    if i == IPDConfig::NOSHOW_IDS - 1
	      raise
	    else
	      i += 1
	      next
	    end
	  end
	else
	  unless @@clients[key].kind_of?(Hash)
	    @@clients[key] = {
	      :created_time => now,
	      :ids => [],
	    }
	  end
	end
	@@clients[key][:ids].push(random_id)
	if @@clients[key][:ids].length > IPDConfig::NOSHOW_IDS
	  @@clients[key][:ids].shift
	end
	break
      end
    rescue Exception => e
      @@log.warn("BAD LUCK RANDOM ID WARNING")
      @@clients[key][:ids] = []
      retry
    end

    return random_id
  end

  attr_accessor :filename, :time_taken, :time_send, :id_user

  def initialize
    @filename = ""
    @time_taken = 0
    @time_send = 0
    @id_user = 0
  end
end
