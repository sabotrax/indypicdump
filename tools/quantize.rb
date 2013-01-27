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
require 'ipdpicture'

result = IPDConfig::DB_HANDLE.execute("SELECT p.filename FROM picture p LEFT JOIN picture_common_color pcc ON p.id = pcc.id_picture WHERE pcc.id_picture IS NULL;")
puts "PICTURES #{result.size}"
result.each do |row|
  begin
    Stalker.enqueue("picture.quantize", :filename => row[0])
  rescue Exception => e
    puts "#{row[0]} #{e.message}"
    next
  end
end
