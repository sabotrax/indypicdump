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
require 'logger'

class IPDUser
  @log = Logger.new(IPDConfig::LOG, IPDConfig::LOG_ROTATION)
  @log.level = IPDConfig::LOG_LEVEL

  attr_accessor :id, :nick, :email, :time_created, :posts

  def self.load(email)
    found = IPDConfig::DB_HANDLE.execute("SELECT u.id, u.nick, u.time_created FROM email_address e INNER JOIN mapping_user_email_address m ON e.id = m.id_address JOIN user u ON u.id = m.id_user WHERE e.address = ?", [email])
    if found.any?
      user = self.new
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
      user.email = email
    else
      user = nil
    end
    return user
  end

  def self.load_by_id(id)
    found = IPDConfig::DB_HANDLE.execute("SELECT * FROM user WHERE id = ?", [id])
    if found.any?
      user = self.new
      user.id = found[0][0]
      user.nick = found[0][1]
      user.time_created = found[0][2]
    else
      user = nil
    end
    return user
  end

  def initialize
    @id = 0
    @nick = ""
    @email = ""
    @time_created = Time.now.to_i
    @posts = 0
  end

  def gen_nick
    adjectives = []
    nouns = []
    adjectives = File.readlines(IPDConfig::ADJECTIVES)
    nouns = File.readlines(IPDConfig::NOUNS)
    # create unique nick from wordlists
    while true do
      nick = adjectives.sample.chomp + " " + nouns.sample.chomp
      #puts "nick " + nick
      found = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", nick)
      #puts "found " + found.size.to_s
      break if found.empty?
    end
    # otherwise insert into db 
    IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [nick, Time.now.to_i])
    self.nick = nick
  end

  def save
    # TODO
    # there's a mysterious bug where new users get saved two times
    # so instead of fixing it, we work around	
    #
    # looks like a sqlite3 bug
    #found = IPDConfig::DB_HANDLE.execute("SELECT id FROM email_address WHERE address = ?", [self.email])
    #return unless found.empty?

    # TODO
    # commit/rollback
    IPDConfig::DB_HANDLE.execute("INSERT INTO user (nick, time_created) VALUES (?, ?)", [self.nick, self.time_created])
    result = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", [self.nick])
    self.id = result[0][0]
    IPDConfig::DB_HANDLE.execute("INSERT INTO email_address (address, time_created) VALUES (?, ?)", [self.email, self.time_created])
    result = IPDConfig::DB_HANDLE.execute("SELECT id FROM email_address WHERE address = ?", [self.email])
    IPDConfig::DB_HANDLE.execute("INSERT INTO mapping_user_email_address (id_user, id_address) VALUES (?, ?)", [self.id, result[0][0]])
  end
end
