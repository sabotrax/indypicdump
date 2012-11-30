require "sqlite3"
require "logger"
require '/home/schommer/dev/indypicdump/ipdconfig'

class IPDPicture
  @@log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
  @@log.level = IPDConfig::LOG_LEVEL

  @last_random_id = 0
  @random_pool = []

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

      # TODO
      # catch random.org offline error
      randnum = []
      generator = RealRand::RandomOrg.new
      randnum = generator.randnum(IPDConfig::GEN_RANDOM_IDS, 0, result[0][0] - 1)
      #puts "COUNT RANDNUMS " + randnum.length.to_s
      
      @random_pool = randnum
    end
    @random_pool.shift
  end

  attr_accessor :filename, :time_taken, :time_send, :id_user

  def initialize
    @filename = ""
    @time_taken = 0
    @time_send = 0
    @id_user = 0
  end
end
