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

# Copyright 2012-2015 Marcus Schommer <sabotrax@gmail.com>

require 'ipdhelper'

class IPDUser
  ##############################
  def self.load(u)
    result = []
    user = nil
    if u.to_s =~ /^[1-9]\d*$/
      result = DB_HANDLE.execute("SELECT * FROM user WHERE id = ?", [u])
    elsif u =~ /^[a-z\- ]+(?<!-)$/i
      result = DB_HANDLE.execute("SELECT * FROM user WHERE nick = ?", [u.undash])
    elsif u =~ /#{REGEX_EMAIL}/i
      result = DB_HANDLE.execute("SELECT u.id, u.nick, u.time_created, u.accept_external_messages FROM email_address e JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE e.address = ?", [u])
    end
    if result.any?
      user = self.new
      user.id = result[0][0]
      user.nick = result[0][1]
      user.time_created = result[0][2]
      user.accept_external_messages = result[0][3]
      email = DB_HANDLE.execute("SELECT e.* FROM email_address e JOIN mapping_user_email_address m JOIN user u WHERE e.id = m.id_address AND m.id_user = u.id AND u.id = ?", [user.id])
      email.each do |row|
	user.email = row[1]
      end
    end
    return user
  end

  ##############################
  def self.exists?(u)
    user = self.load(u)
    if user
      return true
    else
      return false
    end
  end

  attr_accessor :id, :nick, :time_created, :posts, :nick_w_title

  ##############################
  def initialize
    @id = 0
    @nick = _gen_nick
    @email = []
    @time_created = Time.now.to_i
    @posts = 0
    @has_messages = false
    @accept_external_messages = false
    @nick_w_title = ""
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
    raise IPDUserError, "EMAIL MISSING ERROR" if self.email.empty?
    try = 0
    begin
      DB_HANDLE.transaction if try == 0
      if self.id == 0
	DB_HANDLE.execute("INSERT INTO user (nick, time_created, accept_external_messages) VALUES (?, ?, ?)", [self.nick, self.time_created, self.accept_external_messages])
	result = DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	self.id = result[0][0]
	self.email.each do |address|
	  DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [address, self.time_created])
	  result = DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	  DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
	end
	DB_HANDLE.execute("CREATE VIEW \"ud#{self.id}\" AS SELECT * FROM picture WHERE id_user = #{self.id}")
      else
	DB_HANDLE.execute("UPDATE user SET nick = ?, accept_external_messages = ? WHERE id = ?", [self.nick, self.accept_external_messages, self.id])
	# remove addresses that are no longer in the object
	result = DB_HANDLE.execute("SELECT e.id, e.address FROM email_address e JOIN mapping_user_email_address m ON e.id = m.id_address WHERE m.id_user = ? ORDER BY e.id ASC", [self.id])
	result.each do |row|
	  unless self.has_email?(row[1])
	    DB_HANDLE.execute("DELETE FROM mapping_user_email_address WHERE id_user = ? AND id_address = ?", [self.id, row[0]])
	    DB_HANDLE.execute("DELETE FROM email_address WHERE id = ?", [row[0]])
	  end
	end
	# insert new addresses
	now = Time.now
	self.email.each do |address|
	  result = DB_HANDLE.execute("SELECT id FROM email_address WHERE address = ?", [address])
	  if result.empty?
	    DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [address, now.to_i])
	    result = DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	    DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
	  end
	end
      end
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 7
        DB_HANDLE.rollback
        LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE SAVING USER #{self.email.to_s} / #{e.message} / #{e.backtrace.shift}")
        raise
      end
      retry
    rescue SQLite3::Exception => e
      DB_HANDLE.rollback
      LOG_HANDLE.fatal("DB ERROR WHILE SAVING USER #{self.email.to_s} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    DB_HANDLE.commit
  end

  ##############################
  def has_messages?
    if self.id != 0
      result = DB_HANDLE.execute("SELECT id FROM message WHERE id_user = ? AND time_created >= ?", [self.id, Time.now.to_i - MSG_SHOW_SPAN])
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
      result = DB_HANDLE.execute("SELECT id FROM picture WHERE id = ? AND id_user = ?", [id_picture, self.id])
    end
    owns_picture = true if result.any?
    return owns_picture
  end

  ##############################
  def admin_of_dump?(d)
    admin_of_dump = false
    dump = IPDDump.load(d)
    if dump and dump.has_user?(self.id)
      admin_of_dump = true if dump.user[self.id][:admin] == 1
    end
    return admin_of_dump
  end

  private

  ##############################
  def _gen_nick
    adjectives = []
    nouns = []
    adjectives = File.readlines(ADJECTIVES)
    nouns = File.readlines(NOUNS)
    max_nicks = adjectives.length * nouns.length
    # create unique nick from wordlists
    nick = ""
    i = 0
    reserved = File.readlines(RESERVED_NICKS)
    while true do
      nick = adjectives.sample.chomp + " " + nouns.sample.chomp
      result = DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", nick)
      break if result.empty? and !reserved.include?(nick + "\n")
      if i > max_nicks
	LOG_HANDLE.fatal("MAX NUMBERS OF NICKS ERROR #{self.email}")
	raise "MAX NUMBERS OF NICKS ERROR #{self.email}"
      end
      i += 1
    end
    return nick
  end
end
