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

unless ARGV.length == 1
  puts "ARGUMENT ERROR, GIVE FILE"
  exit
end

filename = ARGV.shift

lines = IO.readlines(filename)
puts "LINES #{lines.size}"
lol = []
lines.each do |line|
  lol << line.split("#").map {|l| l.strip}
end
lol.each do |l|
  l[1].sub!(/(\h{6})\s+.*$/, '\1')
end
puts "COLORS #{lol.size}"
File.open(filename + "-processed", 'w') do |f|
  lol.each do |line|
    f.write("\##{line[1]}, #{line[0]}\n")
  end
end
