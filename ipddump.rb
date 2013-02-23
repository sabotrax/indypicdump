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

class IPDDump
  @dump = {}

  class << self
    attr_accessor :dump
  end

  ##############################
  def self.load_dump_map
    dump = self.dump
    return dump if dump.any?
    result = IPDConfig::DB_HANDLE.execute("SELECT * FROM dump ORDER BY id ASC")
    result.each do |row|
      # catch SQLite duplicate inserts bug
      next if dump.has_key?(row[1])
      dump[row[1]] = row[0]
    end
    self.dump = dump
  end

  ##############################
  def self.reload_dump_map
    self.dump = {}
    self.load_dump_map
  end

  ##############################
  def self.exists?(s)
    dump_exists = false
    dump_exists = true if id_dump(s) != 0
    return dump_exists
  end

  ##############################
  def self.id_dump(s)
    id_dump = 0
    dump_alias = s.downcase
    dump_alias.sub!(/@.+$/, "")
    dump_alias.tr!(" ", "-")
    id_dump = dump[dump_alias] if dump.has_key?(dump_alias)
    return id_dump
  end

  ##############################
  def self.load(d)
    result = []
    dump = nil
    if d.to_s =~ /^[1-9]\d*$/
      result = IPDConfig::DB_HANDLE.execute("SELECT * FROM dump WHERE id = ?", [d])
    elsif d =~ /^[a-z\- ]+(?<!-)$/i
      result = IPDConfig::DB_HANDLE.execute("SELECT * FROM dump WHERE alias = ?", [d.dash])
    end
    if result.any?
      dump = self.new
      dump.id = result[0][0]
      dump.alias = result[0][1]
      dump.time_created = result[0][2]
      dump.state = result[0][3]
      dump.password = result[0][4]
    end
    return dump
  end

  attr_accessor :id, :alias, :time_created, :user, :state, :password

  ##############################
  def initialize
    @id = 0
    @alias = ""
    @time_created = Time.now.to_i
    @state = "open"
    @password = ""
    @user = []
  end

  ##############################
  def save
    if self.alias.empty? or self.state == "protected" and self.password.empty?
      raise IPDDumpError, "DUMP INCOMPLETE ERROR"
    end
    try = 0
    begin
      IPDConfig::DB_HANDLE.transaction if try == 0
      IPDConfig::DB_HANDLE.execute("INSERT INTO dump (alias, time_created, state, password) VALUES (?, ?, ?, ?)", [self.alias, self.time_created, self.state, self.password])
      result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
      self.id = result[0][0]
      IPDConfig::DB_HANDLE.execute("CREATE VIEW \"#{self.id}\" AS SELECT * FROM picture WHERE id_dump = #{self.id}")
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 7
        IPDConfig::DB_HANDLE.rollback
        IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE SAVING DUMP #{self.alias} / #{e.message} / #{e.backtrace.shift}")
        raise
      end
      retry
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE SAVING DUMP #{self.alias} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end

  ##############################
  def has_user?(u)
    result = []
    has_user = false
    if u.to_s =~ /^[1-9]\d*$/
      result = IPDConfig::DB_HANDLE.execute("SELECT id_dump FROM mapping_dump_user WHERE id_dump = ? AND id_user = ?", [self.id, u])
    elsif u =~ /#{IPDConfig::REGEX_EMAIL}/i
      result = IPDConfig::DB_HANDLE.execute("SELECT d.id FROM dump d JOIN mapping_dump_user m1 ON d.id = m1.id_dump JOIN mapping_user_email_address m2 ON m1.id_user = m2.id_user JOIN email_address e ON m2.id_address = e.id WHERE d.id = ? AND e.address = ?", [self.id, u])
    end
    has_user = true if result.any?
    return has_user
  end

  ##############################
  def add_user(u)
    raise ArgumentError unless u.to_s =~ /^[1-9]\d*$/
    try = 0
    begin
      IPDConfig::DB_HANDLE.transaction if try == 0
      result = IPDConfig::DB_HANDLE.execute("SELECT id_dump FROM mapping_dump_user WHERE id_dump = ? AND id_user = ?", [self.id, u])
      raise IPDDumpError, "USER ALREADY IN DUMP ERROR" if result.any?
      IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_dump_user (id_dump, id_user) VALUES (?, ?)", [self.id, u])
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 7
        IPDConfig::DB_HANDLE.rollback
        IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE ADDING USER TO DUMP #{u} -> #{self.alias} / #{e.message} / #{e.backtrace.shift}")
        raise
      end
      retry
    rescue IPDDumpError, SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE ADDING USER TO DUMP #{u} -> #{self.alias} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end

  ##############################
  def open!
    @state = "open"
    @password = ""
  end

  ##############################
  def open?
    if @state == "open"
      return true
    else
      return false
    end
  end

  ##############################
  def hide!
    @state = "hidden"
    @password = ""
  end

  ##############################
  def hidden?
    if @state == "hidden"
      return true
    else
      return false
    end
  end

  ##############################
  def protect!
    @state = "protected"
  end

  ##############################
  def protected?
    if @state == "protected"
      return true
    else
      return false
    end
  end

end
