require "sqlite3"

# setup
DB = "horrible.db"

class IPDUser
  attr_accessor :id, :nick, :email, :time_created

  def self.load(email)
    # TODO
    # geht das besser (db)?
    db = SQLite3::Database.new DB
    found = db.execute("SELECT u.id, u.nick, u.time_created FROM email_address e INNER JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE e.address = ?", [email])
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
    # TODO
    # geht das besser (db)?
    db = SQLite3::Database.new DB
    adjectives = []
    nouns = []
    adjectives = File.readlines(IPDConfig::ADJECTIVES)
    nouns = File.readlines(IPDConfig::NOUNS)
    # create unique nick from wordlists
    while true do
      nick = adjectives.sample.chomp + " " + nouns.sample.chomp
      #puts "nick " + nick
      found = db.execute("SELECT id FROM user WHERE nick = ?", nick)
      #puts "found " + found.size.to_s
      break if found.empty?
    end
    # otherwise insert into db 
    db.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [nick, Time.now.to_i])
    self.nick = nick
  end

  def save
    # TODO
    # geht das besser (db)?
    db = SQLite3::Database.new DB
    db.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [self.nick, self.time_created])
    result = db.execute("SELECT id from user where nick = ?", [self.nick])
    self.id = result[0][0]
    db.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [self.email, self.time_created])
    result = db.execute("SELECT id from email_address where address = ?", [self.email])
    db.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
  end
end
