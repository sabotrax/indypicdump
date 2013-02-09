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

require 'sqlite3'
require "random/online"
require 'RMagick'

class IPDPicture
  @random_pool = {}
  @clients = {}

  class << self
    attr_accessor :random_pool
    attr_reader :clients
  end

  ##############################
  def self.get_weighted_random_id(request)
  #def self.get_weighted_random_id(d)
    require "ipdtest"

    id_dump = IPDDump.dump[request.dump] || request.dump
    #id_dump = d
    @random_pool[id_dump] = [] unless @random_pool.has_key?(id_dump)
    if @random_pool[id_dump].empty?
      IPDConfig::LOG_HANDLE.info("RANDOM POOL EMPTY DUMP #{id_dump}")
      result = []
      result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM \"#{id_dump}\"")
      raise DumpEmpty, "DUMP EMPTY DUMP #{id_dump}" if result[0][0] == 0

      randnum = []
      begin
	# one-picture-dumps just aren't random
	if result[0][0] == 1
	  (1..IPDConfig::GEN_RANDOM_IDS).each { randnum.push([0]) }
	else
	  generator = RealRand::RandomOrg.new
	  randnum = generator.randnum(IPDConfig::GEN_RANDOM_IDS, 0, result[0][0] - 1)
	end
      # TODO
      # retry? (The Ruby Programming Language, 162)
      # better use own error class vs. catchall
      rescue Exception => e
	IPDConfig::LOG_HANDLE.error("RANDOM NUMBER FETCH ERROR #{e}")
	IPDConfig::LOG_HANDLE.info("USING FALLBACK RANDOM NUMBER GENERATOR")
	(1..IPDConfig::GEN_RANDOM_IDS).each { randnum.push(rand(result[0][0])) }
      end

      #puts IPDTest.random_distribution(1000, randnum)

      # show newer pics more often
      span = Time.now.to_i - IPDConfig::PICTURE_DISPLAY_MOD_SPAN
      # get new pictures
      result = IPDConfig::DB_HANDLE.execute("SELECT (SELECT COUNT(0) - 1 FROM \"#{id_dump}\" p1 WHERE p1.id <= p2.id) as 'rownum', filename FROM \"#{id_dump}\" p2 WHERE time_sent > ?", [span])
      result.each do |row|
	offset = row[0]
	# create random positions for later injection
	weighted = []
	(1..(IPDConfig::GEN_RANDOM_IDS * IPDConfig::PICTURE_DISPLAY_MOD).to_i).each do
	  weighted.push(rand(randnum.length))
	end
	# merge
	weighted.each do |p|
	  randnum.insert(p, offset)
	end
      end
      #puts IPDTest.random_distribution(1000, randnum)

      # NOTE
      # here we translate random numbers to picture ids
      # remove some groups (as they would be to dominant)
      # and complete the rest
      remove_groups = (IPDConfig::GEN_RANDOM_IDS * IPDConfig::GROUP_NEGATIVE_DISPLAY_MOD).to_i
      step = IPDConfig::GEN_RANDOM_IDS / remove_groups
      # random ids with group pictures
      randid = []
      i = 0
      removed = 0
      randnum.each do |n|
	result = IPDConfig::DB_HANDLE.execute("SELECT id, successor FROM \"#{id_dump}\" LIMIT ?, 1", [n])
	if result[0][1] != 0 and i >= removed * step
	  if removed < remove_groups
	    removed += 1
	    i += 1
	    next
	  end
	end
	i += 1
	randid << result[0][0]
	# get second and third picture of group
	if result[0][1] != 0
	  randid << result[0][1]
	  result2 = IPDConfig::DB_HANDLE.execute("SELECT successor FROM picture WHERE id = ?", result[0][1])
	  randid << result2[0][0]
	  # TODO
	  # raise error unless group is complete
	end
      end

      @random_pool[id_dump] = randid
    end
    @random_pool[id_dump].shift
  end

  ##############################
  # - generate smart random ids
  # so the last IPDConfig::NOSHOW_LAST_IDS won't be drawn again
  # - this works per client with a IPDConfig::CLIENT_TIMEOUT second timeout 
  # 
  # request = sinatra request object
  def self.get_smart_random_id(request)
    # identify client
    key = Digest::RMD160::hexdigest(request.ip + request.user_agent).to_sym
    # and dump
    # multi or user dump
    id_dump = IPDDump.dump[request.dump] || request.dump

    now = Time.now.to_i
    # update recurring clients
    if @clients.has_key?(key) and @clients[key].has_key?(id_dump)
      @clients[key][id_dump][:time_created] = now
    end
    
    # - an array of [some_id, other_id, third_id,] could get new ids array.length times
    # that are already members
    # we then clear the array
    begin
      i = 0

      # find non-sequential id
      while true do
	random_id = self.get_weighted_random_id(request)
	# TODO
	# this is expensive
	# better add precursor earlier by making "random_id" a hash
	result = IPDConfig::DB_HANDLE.execute("SELECT id, precursor FROM picture WHERE id = ?", [random_id])
	if @clients.has_key?(key) and @clients[key].has_key?(id_dump)
	  # skip pictures with precursors
	  if result[0][1] == @clients[key][id_dump][:last_skipped]
	    @clients[key][id_dump][:last_skipped] = result[0][0]
	    next
	  end
	  if @clients[key][id_dump][:ids].include?(random_id)
	    if i == IPDConfig::NOSHOW_LAST_IDS - 1
	      raise BadLuck, "BAD LUCK RANDOM ID WARNING DUMP #{id_dump}"
	    else
	      i += 1
	      @clients[key][id_dump][:last_skipped] = random_id
	      next
	    end
	  end
	else
	  unless @clients[key].kind_of?(Hash)
	    @clients[key] = {}
	  end
	  unless @clients[key][id_dump].kind_of?(Hash)
	    @clients[key][id_dump] = {
	      :time_created => now,
	      :ids => [],
	      :last_skipped => 0
	    }
	  end
	end
	@clients[key][id_dump][:ids].push(random_id)
	if @clients[key][id_dump][:ids].length > IPDConfig::NOSHOW_LAST_IDS
	  @clients[key][id_dump][:ids].shift
	end
	break
      end
    rescue DumpEmpty => e
      IPDConfig::LOG_HANDLE.info(e.message)
      raise
    rescue BadLuck => e
      IPDConfig::LOG_HANDLE.warn(e.message)
      @clients[key][id_dump][:ids] = []
      retry
    end

    return random_id
  end

  ##############################
  def self.load(p)
    result = []
    picture = nil
    if p.to_s =~ /^[1-9]\d*$/
      result = IPDConfig::DB_HANDLE.execute("SELECT p.*, d.alias FROM picture p JOIN dump d ON p.id_dump = d.id WHERE p.id = ?", [p])
    elsif p =~ /^\d+\.(\d+\.)?[a-z]{3,4}$/i
      result = IPDConfig::DB_HANDLE.execute("SELECT p.*, d.alias FROM picture p JOIN dump d ON p.id_dump = d.id WHERE p.filename = ?", [p])
    end
    if result.any?
      picture = self.new
      picture.id = result[0][0]
      picture.filename = result[0][1]
      picture.time_taken = result[0][2]
      picture.time_sent = result[0][3]
      picture.id_user = result[0][4]
      picture.original_hash = result[0][5]
      picture.id_dump = result[0][6]
      picture.path = result[0][7]
      picture.precursor = result[0][8]
      picture.successor = result[0][9]
      picture.no_show = result[0][10]
      picture.dump = result[0][11]
    end
    return picture
  end

  ##############################
  def self.exists?(p)
    result = []
    picture_exists = false
    if p =~ /^\d+\.(\d+\.)?[a-z]{3,4}$/i
      result = IPDConfig::DB_HANDLE.execute("SELECT id, path FROM picture WHERE filename = ?", [p])
    end
    if result.any?
      if File.exists?(IPDConfig::PICTURE_DIR + "/" + result[0][1] + "/" + p)
	picture_exists = result[0][0]
      else
	IPDConfig::LOG_HANDLE.error("PICTURE MISSING ERROR #{result[0][1]}/#{p} in #{caller[0]}")
      end
    end
    return picture_exists
  end

  ##############################
  def self.count_pictures
    result = IPDConfig::DB_HANDLE.execute("SELECT COUNT(*) FROM picture")
    return result[0][0]
  end

  ##############################
  def self.delete(p)
    raise ArgumentError unless p.to_s =~ /^[1-9]\d*$/
    remove_ids = _find_group(p)
    remove_ids << p if remove_ids.empty?
    try = 0
    files = []
    begin
      IPDConfig::DB_HANDLE.transaction if try == 0
      remove_ids.each do |id|
	result = IPDConfig::DB_HANDLE.execute("SELECT path, filename FROM picture WHERE id = ?", [id])
	raise PictureMissing, "PICTURE NOT IN DB" unless result.any?
	IPDConfig::DB_HANDLE.execute("DELETE FROM picture WHERE id = ?", [id])
	IPDConfig::DB_HANDLE.execute("DELETE FROM picture_common_color WHERE id_picture = ?", [id])
	files << result[0][0] + "/"  + result[0][1]
      end
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 14
        IPDConfig::DB_HANDLE.rollback
        IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE DELETING PICTURE IDS #{remove_ids.to_s} / #{e.message} / #{e.backtrace.shift}")
        raise
      end
      retry
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE DELETING PICTURE IDS #{remove_ids.to_s} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
    begin
      files.each do |file|
	File.unlink(IPDConfig::PICTURE_DIR + "/" + file)
      end
    rescue Exception => e
      IPDConfig::LOG_HANDLE.fatal("FILE ERROR WHILE DELETING PICTURE #{files.to_s} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
  end

  ##############################
  def self._find_group(*ids)
    ids.flatten!
    result = IPDConfig::DB_HANDLE.execute("SELECT precursor, successor FROM picture WHERE (precursor != 0 OR successor != 0) AND id = ?", [ids.last])
    if result.any?
      if result[0][0] != 0 and !ids.include?(result[0][0])
	ids << result[0][0]
	ids += _find_group(ids)
      end
      if result[0][1] != 0 and !ids.include?(result[0][1])
	ids << result[0][1]
	ids +=  _find_group(ids)
      end
    else
      ids.shift
    end
    return ids.uniq.sort
  end
  #private_class_method :_find_group

  ##############################
  def self.load_group(id)
    # TODO
    # add argument check
    group = []
    _find_group(id).each do |i|
      group << self.load(i)
    end
    return group
  end

  ##############################
  attr_accessor :id, :filename, :time_taken, :time_sent, :id_user, :original_hash, :id_dump, :path, :dump, :precursor, :successor, :no_show

  ##############################
  def initialize
    @id = 0
    @filename = ""
    @time_taken = 0
    @time_sent = 0
    @id_user = 0
    @original_hash = ""
    @id_dump = 0
    @path = ""
    @dump = ""
    @precursor = 0
    @successor = 0
    @no_show = 0
  end

  ##############################
  # returns the most common colors of a picture
  # as [[r, g, b], ..]
  def quantize
    image = Magick::ImageList.new(IPDConfig::PICTURE_DIR + "/" + self.path + "/" + self.filename)
    colors = []
    # we're looking for the 7 most common colors
    q = image.quantize(7, Magick::RGBColorspace)
    palette = q.color_histogram.sort {|a, b| b[1] <=> a[1]}
    (0..6).each do |i|
      c = palette[i].to_s.split(',').map {|x| x[/\d+/]}
      c.pop
      c[0], c[1], c[2] = [c[0], c[1], c[2]].map { |s| 
	s = s.to_i
	if s / 255 > 0 # not all ImageMagicks are created equal....
	  s = s / 255
	end
	s
      }
      c = c.slice(0..2)
      colors << c
    end
    return colors
  end

  ##############################
  # returns
  # [] of the approximated names of the most common colors of the picture
  def approx_common_color
    result = IPDConfig::DB_HANDLE.execute("SELECT color FROM picture_common_color WHERE id_picture = ?", [self.id])
    mcc = result[0][0].split(",")
    raise PictureCommonColorMissing if mcc.empty?
    loc = File.readlines(IPDConfig::COLORS)
    colors = {}
    loc.each do |line|
      a = line.split(",").map {|l| l.strip.chomp}
      colors[a[0]] = a[1]
    end
    approx_color_name = []
    mcc.each do |cc|
      m = cc.match(/(..)(..)(..)/)
      cc = [m[1].hex, m[2].hex, m[3].hex]
      distance = 255 * 3
      approx_color = "#000000"
      colors.each_key do |color|
	m = color.match(/#(..)(..)(..)/)
	c = [m[1].hex, m[2].hex, m[3].hex]
	r_dist = (cc[0].abs2 - c[0].abs2).abs
	g_dist = (cc[1].abs2 - c[1].abs2).abs
	b_dist = (cc[2].abs2 - c[2].abs2).abs
	new_distance = Math.sqrt(r_dist + g_dist + b_dist).to_i
	if new_distance < distance
	  distance = new_distance
	  approx_color = color
	end
      end
      approx_color_name << colors[approx_color]
    end
    return approx_color_name
  end

  ##############################
  def save
    if self.filename.empty? or self.time_sent == 0 or self.id_user == 0 or self.original_hash.empty? or self.id_dump == 0 or self.path.empty?
      raise IPDPictureError, "PICTURE INCOMPLETE ERROR"
    end
    try = 0
    begin
      IPDConfig::DB_HANDLE.transaction if try == 0
      if self.id == 0
	IPDConfig::DB_HANDLE.execute("INSERT INTO picture (filename, time_taken, time_sent, id_user, original_hash, id_dump, path, precursor, successor, no_show) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)", [self.filename, self.time_taken, self.time_sent, self.id_user, self.original_hash, self.id_dump, self.path, self.precursor, self.successor, self.no_show])
	result = IPDConfig::DB_HANDLE.execute("SELECT LAST_INSERT_ROWID()")
	self.id = result[0][0]
      else
	IPDConfig::DB_HANDLE.execute("UPDATE picture SET filename = ?, time_taken = ?, time_sent = ?, id_user = ?, original_hash = ?, id_dump = ?, path = ?, precursor = ?, successor = ?, no_show = ? WHERE id = ?", [self.filename, self.time_taken, self.time_sent, self.id_user, self.original_hash, self.id_dump, self.path, self.precursor, self.successor, self.no_show, self.id])
      end
    rescue SQLite3::BusyException => e
      sleep 1
      try += 1
      if try == 7
	IPDConfig::DB_HANDLE.rollback
	IPDConfig::LOG_HANDLE.fatal("DB PERMANENT LOCKING ERROR WHILE SAVING PICTURE #{self.filename} / #{e.message} / #{e.backtrace.shift}")
	raise
      end
      retry
    rescue SQLite3::Exception => e
      IPDConfig::DB_HANDLE.rollback
      IPDConfig::LOG_HANDLE.fatal("DB ERROR WHILE SAVING PICTURE #{self.filename} / #{e.message} / #{e.backtrace.shift}")
      raise
    end
    IPDConfig::DB_HANDLE.commit
  end

  ##############################
  def in_group?
    in_group = false
    if self.precursor != 0 or self.successor != 0
      in_group = true
    end
    return in_group
  end

  ##############################
  def group_ids
    self.class._find_group self.id 
  end

  ##############################
  def no_show!
    @no_show = 1
  end
  
  ##############################
  def no_show?
    if @no_show == 1
      return true
    else
      return false
    end
  end
  
  ##############################
  def show!
    @no_show = 0
  end

  ##############################
  def show?
    if @no_show == 0
      return true
    else
      return false
    end
  end
end
