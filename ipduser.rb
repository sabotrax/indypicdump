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

require 'ipdhelper'

class IPDUser
  attr_accessor :id, :nick, :time_created, :posts

  ##############################
  def self.load_by_email(email)
    found = IPDConfig::DB_HANDLE.execute("SELECT u.id, u.nick, u.time_created FROM email_address e INNER JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE e.address = ?", [email])
    if found.any?
      user = self.new
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
      result = IPDConfig::DB_HANDLE.execute("SELECT e.* FROM email_address e JOIN mapping_user_email_address m JOIN user u WHERE e.id = m.id_address AND m.id_user = u.id AND u.id = ?", [user.id])
      result.each do |row|
	user.email = row[1]
      end
    else
      user = nil
    end
    return user
  end

  ##############################
  def self.load_by_id(id)
    found = IPDConfig::DB_HANDLE.execute("SELECT * FROM user WHERE id = ?", [id])
    if found.any?
      user = self.new
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
      email = IPDConfig::DB_HANDLE.execute("SELECT e.* FROM email_address e JOIN mapping_user_email_address m JOIN user u WHERE e.id = m.id_address AND m.id_user = u.id AND u.id = ?", [id])
      email.each do |row|
	user.email = row[1]
      end
    else
      user = nil
    end
    return user
  end

  ##############################
  def self.load_by_nick(nick)
    found = IPDConfig::DB_HANDLE.execute("SELECT * FROM user WHERE nick = ?", [nick.undash])
    if found.any?
      user = self.new
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
      email = IPDConfig::DB_HANDLE.execute("SELECT e.* FROM email_address e JOIN mapping_user_email_address m JOIN user u WHERE e.id = m.id_address AND m.id_user = u.id AND u.id = ?", [user.id])
      email.each do |row|
	user.email = row[1]
      end
    else
      user = nil
    end
    return user
  end

  ##############################
  def self.is_user?(i)
    result = []
    is_user = false
    if i =~ /^[1-9]\d*$/
      result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user WHERE id = ?", [i])
    elsif i =~ /^[a-zA-Z\- ]+$/
      result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user WHERE nick = ?", [i.undash])
    end
    is_user = true if result.any?
    return is_user
  end

  ##############################
  def initialize
    @id = 0
    @nick = ""
    @email = []
    @time_created = Time.now.to_i
    @posts = 0
    @has_messages = false
  end

  ##############################
  def email=(email)
    if email.kind_of? Array
      @email = email
    else
      @email.push(email)
    end
  end

  ##############################
  def email
    @email
  end

  ##############################
  def gen_nick
    adjectives = []
    nouns = []
    adjectives = File.readlines(IPDConfig::ADJECTIVES)
    nouns = File.readlines(IPDConfig::NOUNS)
    max_nicks = adjectives.length * nouns.length
    # create unique nick from wordlists
    i = 0
    while true do
      nick = adjectives.sample.chomp + " " + nouns.sample.chomp
      found = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", nick)
      break if found.empty?
      if i > max_nicks
	IPDConfig::LOG_HANDLE.fatal("MAX NUMBERS OF NICKS ERROR #{self.email}")
	raise "MAX NUMBERS OF NICKS ERROR #{self.email}"
      end
      i += 1
    end
    # otherwise insert into db 
    IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [nick, Time.now.to_i])
    self.nick = nick
  end

  ##############################
  def save
    # TODO
    # there's a mysterious bug where new users get saved two times
    # so instead of fixing it, we work around	
    #
    # looks like a sqlite3 bug
    #found = IPDConfig::DB_HANDLE.execute("SELECT id FROM email_address WHERE address = ?", [self.email])
    #return unless found.empty?

    # TODO
    # add raise like in other save methods
    begin
      IPDConfig::DB_HANDLE.transaction
      IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [self.nick, self.time_created])
      result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
      self.id = result[0][0]
      self.email.each do |address|
	IPDConfig::DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [address, self.time_created])
	result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
      end
      IPDConfig::DB_HANDLE.execute("CREATE VIEW \"ud#{self.id}\" AS SELECT * FROM picture WHERE id_user = #{self.id}")
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE SAVING USER #{self.email.to_s} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end

  ##############################
  def has_messages?
    if self.id != 0
      result = IPDConfig::DB_HANDLE.execute("SELECT * FROM message WHERE id_user = ? AND time_created >= ?", [self.id, Time.now.to_i - IPDConfig::MSG_SHOW_SPAN])
      @has_messages = true if result.any?
    end
    return @has_messages
  end
end
