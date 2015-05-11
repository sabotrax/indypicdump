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

# Copyright 2012-2015 Marcus Schommer <sabotrax@gmail.com>

unless ARGV.length == 1
  puts "ARGUMENT ERROR, GIVE FILE"
  exit
end

filename = ARGV.shift

words = IO.readlines(filename)
words.each {|w| w.chomp! }
puts "WORDS " + words.length.to_s

unique_words = words.uniq
unique_words.sort! {|x, y| x <=> y }
puts "UNIQUE " + unique_words.length.to_s

File.open(filename + "-unique", 'w') {|f| f.write(unique_words.join("\n")) }
