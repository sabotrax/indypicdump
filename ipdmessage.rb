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

class IPDMessage
  attr_accessor :id, :message_id, :message_text, :time_created, :id_user

  ##############################
  def initialize
    @id = 0
    @message_id = 0
    @message_text = ""
    @time_created = Time.now.to_i
    @id_user = 0
  end

  ##############################
  def save
    if self.message_id == 0 or self.id_user == 0
      raise
    end
    IPDConfig::DB_HANDLE.transaction
    IPDConfig::DB_HANDLE.execute("INSERT INTO message (message_id, time_created, id_user) VALUES (?, ?, ?)", [self.message_id, self.time_created, self.id_user])
    result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
    self.id = result[0][0]
    IPDConfig::DB_HANDLE.commit
  end
end
