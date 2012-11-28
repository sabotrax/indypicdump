class IPDPicture
  @last_random_id = 0

  def self.last_random_id
    @last_random_id
  end

  def self.last_random_id=(id)
    @last_random_id = id
  end

  attr_accessor :filename, :time_taken, :time_send, :id_user

  def initialize
    @filename = ""
    @time_taken = 0
    @time_send = 0
    @id_user = 0
  end
end
