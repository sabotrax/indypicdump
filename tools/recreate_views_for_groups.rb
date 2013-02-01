#!/usr/bin/ruby -w

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

$:.unshift("/home/schommer/dev/indypicdump")

require 'sqlite3'
require 'stalker'
require 'ipdconfig'
require 'ipderror'

result = IPDConfig::DB_HANDLE.execute("SELECT id FROM dump ORDER BY id ASC")
result.each do |row|
  begin
    IPDConfig::DB_HANDLE.execute("DROP VIEW \"#{row[0]}\"")
  rescue SQLite3::Exception => e
    puts e.message
    print "GO ON (Y/N) "
    a = gets.chomp
    break unless a =~ /y/i
  end
  IPDConfig::DB_HANDLE.execute("CREATE VIEW \"#{row[0]}\" AS SELECT * FROM picture WHERE id_dump = #{row[0]} AND precursor = 0")
end

result = IPDConfig::DB_HANDLE.execute("SELECT id FROM user ORDER BY id ASC")
result.each do |row|
  begin
    IPDConfig::DB_HANDLE.execute("DROP VIEW \"ud#{row[0]}\"")
  rescue SQLite3::Exception => e
    puts e.message
    print "GO ON (Y/N) "
    a = gets.chomp
    break unless a =~ /y/i
  end
  IPDConfig::DB_HANDLE.execute("CREATE VIEW \"ud#{row[0]}\" AS SELECT * FROM picture WHERE id_user = #{row[0]} AND precursor = 0")
end
