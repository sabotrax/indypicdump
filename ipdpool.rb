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

class IPDPool
  @pool = {}

  class << self
    attr_accessor :pool
  end

  def self.load
    pool = self.pool
    return pool if pool.any?
    result = IPDConfig::DB_HANDLE.execute("SELECT * FROM pool ORDER BY id ASC")
    result.each do |row|
      # catch SQLite duplicate inserts bug
      next if pool.has_key?(row[1])
      pool[row[1]] = row[0]
    end
    self.pool = pool
  end

  def self.reload
    self.pool = {}
    self.load
  end

  attr_accessor :id, :alias, :time_created

  def initialize
    @id = 0
    @alias = ""
    @time_created = Time.now.to_i
  end
end
