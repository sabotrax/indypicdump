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

require 'securerandom'

class IPDRequest
  ##############################
  def self.remove_by_action(action)
    try = 0
    begin
      IPDConfig::DB_HANDLE.transaction if try == 0
      IPDConfig::DB_HANDLE.execute("DELETE FROM user_request WHERE action = ?", [action])
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 7
        IPDConfig::DB_HANDLE.rollback
        IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE REMOVING REQUEST #{action} / #{e.message} / #{e.backtrace.shift}")
        raise
      end
      retry
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE REMOVING REQUEST #{action} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end

  attr_accessor :id, :action, :time_created
  attr_reader :code

  ##############################
  def initialize
    @id = 0
    @action = ""
    @code = SecureRandom.hex(16).downcase
    @time_created = Time.now.to_i
  end

  ##############################
  def exists?
    raise IPDRequestError, "ACTION MISSING ERROR" if self.action.empty?
    request_exists = false
    action = []
    action.push(self.action)
    sql = ""
    # accept/decline messages
    if self.action =~ /^accept\s/
      other = self.action.sub(/accept/, "decline")
      action.push(other)
    elsif self.action =~ /^decline\s/
      other = self.action.sub(/decline/, "accept")
      action.push(other)
    # open dump/new user
    elsif self.action =~ /^open dump/
      other = self.action.sub(/open dump/, "new user")
      action.push(other)
    # remove pictures
    # no id must be in two or more remove requests
    elsif self.action =~ /^remove pictures/
      remove_action = self.action.split(",")
      remove_ids = remove_action.slice(3..-1)
      remove_action = remove_action.slice(0..2).join(",")
      sql = "SELECT * FROM user_request WHERE action LIKE \"#{remove_action}%\" AND ("
      sql_part = []
      remove_ids.each do |id|
	sql_part << "action LIKE \"%,#{id},%\""
      end
      sql += sql_part.join(" OR ")
      sql += ")"
    # set dump
    # we allow only one state change at a time
    elsif self.action =~ /^set dump/
      set_action = self.action.split(",")
      sql = "SELECT * FROM user_request WHERE action LIKE \"set dump,#{set_action[1]},%\""
    end
    action.each do |a|
      if sql.empty?
	result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user_request WHERE action = ?", [a])
      else
	result = IPDConfig::DB_HANDLE.execute(sql)
      end
      if result.any?
	request_exists = true
	break
      end
    end
    return request_exists
  end

  ##############################
  def save
    raise IPDRequestError, "ACTION MISSING ERROR" if self.action.empty?
    try = 0
    begin
      IPDConfig::DB_HANDLE.transaction if try == 0
      IPDConfig::DB_HANDLE.execute("INSERT INTO user_request (action, code, time_created) VALUES (?, ?, ?)", [self.action, self.code, self.time_created])
      result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
      self.id = result[0][0]
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 7
        IPDConfig::DB_HANDLE.rollback
        IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE SAVING REQUEST #{self.action} / #{e.message} / #{e.backtrace.shift}")
        raise
      end
      retry
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE SAVING REQUEST #{self.action} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end
end
