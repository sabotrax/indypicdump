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
  ##############################
  def self.load_by_email(email)
    found = IPDConfig::DB_HANDLE.execute("SELECT u.id, u.nick, u.time_created, u.accept_external_messages FROM email_address e INNER JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE e.address = ?", [email])
    if found.any?
      user = self.new
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
      user.accept_external_messages = found[0][3]
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
      user.accept_external_messages = found[0][3]
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
      user.accept_external_messages = found[0][3]
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
      result = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE id = ?", [i])
    elsif i =~ /^[a-zA-Z\- ]+(?<!-)$/
      result = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", [i.undash])
    # find email addresses
    # below is my short alternative to http://www.ex-parrot.com/~pdw/Mail-RFC822-Address.html
    elsif i =~ /@/
      result = IPDConfig::DB_HANDLE.execute("SELECT u.id FROM user u JOIN mapping_user_email_address m ON u.id = m.id_user JOIN email_address e ON m.id_address = e.id WHERE e.address = ?", [i])
    end
    is_user = true if result.any?
    return is_user
  end

  attr_accessor :id, :nick, :time_created, :posts

  ##############################
  def initialize
    @id = 0
    @nick = _gen_nick
    @email = []
    @time_created = Time.now.to_i
    @posts = 0
    @has_messages = false
    @accept_external_messages = false
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
  def save
    if self.email.empty?
      raise
    end
    begin
      IPDConfig::DB_HANDLE.transaction
      if self.id == 0
	IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created, accept_external_messages) VALUES (?, ?, ?)", [self.nick, self.time_created, self.accept_external_messages])
	result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	self.id = result[0][0]
	self.email.each do |address|
	  IPDConfig::DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [address, self.time_created])
	  result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	  IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
	end
	IPDConfig::DB_HANDLE.execute("CREATE VIEW \"ud#{self.id}\" AS SELECT * FROM picture WHERE id_user = #{self.id}")
      else
	IPDConfig::DB_HANDLE.execute("UPDATE user SET nick = ?, accept_external_messages = ? WHERE id = ?", [self.nick, self.accept_external_messages, self.id])
	# remove addresses that are no longer in the object
	result = IPDConfig::DB_HANDLE.execute("SELECT e.id, e.address FROM email_address e JOIN mapping_user_email_address m ON e.id = m.id_address WHERE m.id_user = ? ORDER BY e.id ASC", [self.id])
	result.each do |row|
	  unless self.has_email?(row[1])
	    IPDConfig::DB_HANDLE.execute("DELETE FROM mapping_user_email_address WHERE id_user = ? AND id_address = ?", [self.id, row[0]])
	    IPDConfig::DB_HANDLE.execute("DELETE FROM email_address WHERE id = ?", [row[0]])
	  end
	end
	# insert addresses that are new
	now = Time.now
	self.email.each do |address|
	  result = IPDConfig::DB_HANDLE.execute("SELECT id FROM email_address WHERE address = ?", [address])
	  if result.empty?
	    IPDConfig::DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [address, now.to_i])
	    result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	    IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
	  end
	end
      end
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
      result = IPDConfig::DB_HANDLE.execute("SELECT id FROM message WHERE id_user = ? AND time_created >= ?", [self.id, Time.now.to_i - IPDConfig::MSG_SHOW_SPAN])
      @has_messages = true if result.any?
    end
    return @has_messages
  end

  ##############################
  def accept_external_messages
    if @accept_external_messages
      return 1
    else
      return 0
    end
  end

  ##############################
  def accept_external_messages=(i)
    if i == 0
      @accept_external_messages = false
    else
      @accept_external_messages = true
    end
  end

  ##############################
  def accept_external_messages!
    @accept_external_messages = true
  end
  
  ##############################
  def accept_external_messages?
    @accept_external_messages
  end
  
  ##############################
  def decline_external_messages!
    @accept_external_messages = false
  end

  ##############################
  def decline_external_messages?
    !@accept_external_messages
  end

  ##############################
  def has_email?(email)
    has_email = false
    @email.each do |address|
      if email == address
	has_email = true
	break
      end
    end
    return has_email
  end

  ##############################
  def remove_email(email)
    @email.delete(email)
  end

  ##############################
  def owns_picture?(p)
    result = []
    owns_picture = false
    id_picture = IPDPicture.exists?(p)
    if id_picture
      result = IPDConfig::DB_HANDLE.execute("SELECT id FROM picture WHERE id = ? AND id_user = ?", [id_picture, self.id])
    end
    owns_picture = true if result.any?
    return owns_picture
  end

  private

  ##############################
  def _gen_nick
    adjectives = []
    nouns = []
    adjectives = File.readlines(IPDConfig::ADJECTIVES)
    nouns = File.readlines(IPDConfig::NOUNS)
    max_nicks = adjectives.length * nouns.length
    # create unique nick from wordlists
    nick = ""
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
    return nick
  end
end
