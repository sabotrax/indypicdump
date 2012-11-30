require "sqlite3"
require "logger"

class IPDUser
  @@log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
  @@log.level = IPDConfig::LOG_LEVEL

  attr_accessor :id, :nick, :email, :time_created

  def self.load(email)
    found = IPDConfig::DB_HANDLE.execute("SELECT u.id, u.nick, u.time_created FROM email_address e INNER JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE e.address = ?", [email])
    user = self.new
    unless found.empty?
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
      user.email = email
    else
      user = nil
    end
    return user
  end

  def initialize
    @id = 0
    @nick = ""
    @email = ""
    @time_created = Time.now.to_i
  end

  def gen_nick
    adjectives = []
    nouns = []
    adjectives = File.readlines(IPDConfig::ADJECTIVES)
    nouns = File.readlines(IPDConfig::NOUNS)
    # create unique nick from wordlists
    while true do
      nick = adjectives.sample.chomp + " " + nouns.sample.chomp
      #puts "nick " + nick
      found = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", nick)
      #puts "found " + found.size.to_s
      break if found.empty?
    end
    # otherwise insert into db 
    IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [nick, Time.now.to_i])
    self.nick = nick
  end

  def save
    # TODO
    # commit/rollback
    IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [self.nick, self.time_created])
    result = IPDConfig::DB_HANDLE.execute("SELECT id from user where nick = ?", [self.nick])
    self.id = result[0][0]
    IPDConfig::DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [self.email, self.time_created])
    result = IPDConfig::DB_HANDLE.execute("SELECT id from email_address where address = ?", [self.email])
    IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
  end
end
