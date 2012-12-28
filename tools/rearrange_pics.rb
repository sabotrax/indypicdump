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

##############################
# rearrange picture storage
# 
# has been:	picdir/picture.jpg
# should be:	picdir/day/picture.jpg
#
# have:		path column added to IPDPicute and db scheme

$:.unshift("/home/schommer/dev/indypicdump")

require 'sqlite3'
require 'fileutils'
require 'ipdconfig'
require 'ipdpicture'

result = IPDConfig::DB_HANDLE.execute("SELECT id FROM picture ORDER BY id ASC")
puts result.length.to_s + " PIC(S)"
processed = 0
result.each do |row|
  pic = IPDPicture.load(row[0])
  # path not set and picture in pic dir
  if (!pic.path or pic.path == "") and File.exists?(IPDConfig::PIC_DIR + "/" + pic.filename)
    # create day dir
      ts = pic.filename.match(/([0-9]+)\./)[1]
      t = Time.at(ts.to_i)
      t2 = Time.new(t.year, t.month, t.day)
      pic.path = t2.to_i.to_s
      begin
	# update db with new path
	IPDConfig::DB_HANDLE.transaction
	IPDConfig::DB_HANDLE.execute("UPDATE picture SET path = ? WHERE id = ?", [pic.path, pic.id])
	# copy picture to new path
	Dir.mkdir(IPDConfig::PIC_DIR + "/" + pic.path) unless Dir.exists?(IPDConfig::PIC_DIR + "/" + pic.path)
	FileUtils.cp IPDConfig::PIC_DIR + "/" + pic.filename, IPDConfig::PIC_DIR + "/" + pic.path
	processed += 1
      rescue Exception => e
	puts e.inspect
	IPDConfig::DB_HANDLE.rollback
      end
      IPDConfig::DB_HANDLE.commit
  end
end
puts processed.to_s + " PROCESSED"
