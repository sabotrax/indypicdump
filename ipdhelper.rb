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

require 'sinatra'

class Sinatra::Request
  ##############################
  def dump
    # user dump
    if self.path =~ /^\/picture\/show\/user\/([a-z][a-z\-]*)$(?<!-)/i
      result = IPDConfig::DB_HANDLE.execute("SELECT id FROM user WHERE nick = ?", [$1.undash])
      dump = "ud" + result[0][0].to_s if result.any?
    # multi dump
    elsif self.path =~ /^\/([a-z0-9][a-z0-9\-]*)(?<!-)$/i
      dump = $1
    else
      dump = ""
    end
    return dump
  end

  ##############################
  def has_dump?
    if self.dump != ""
      has_dump = true
    else
      has_dump = false
    end
    return has_dump
  end
end

class String
  ##############################
  def dash
    self.to_s.downcase.tr(" ", "-")
  end

  ##############################
  def undash
    self.to_s.downcase.tr("-", " ")
  end
end
