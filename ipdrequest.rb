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
    IPDConfig::DB_HANDLE.execute("DELETE FROM user_request WHERE action = ?", [action])
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
    # accept/decline messages
    if self.action =~ /^accept\s+/i
      other = self.action.sub(/accept/, "decline")
      action.push(other)
    elsif self.action =~ /^decline\s+/i
      other = self.action.sub(/decline/, "accept")
      action.push(other)
    # open dump/new user
    elsif self.action =~ /^open dump/i
      other = self.action.sub(/open dump/, "new user")
      action.push(other)
    end
    action.each do |a|
      result = IPDConfig::DB_HANDLE.execute("SELECT * FROM user_request WHERE action = ?", [a])
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
    begin
      IPDConfig::DB_HANDLE.transaction
      IPDConfig::DB_HANDLE.execute("INSERT INTO user_request (action, code, time_created) VALUES (?, ?, ?)", [self.action, self.code, self.time_created])
      result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
      self.id = result[0][0]
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE SAVING REQUEST #{self.action} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end
end
