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

$:.unshift("#{File.dirname(__FILE__)}/lib")

require 'stalker'
require 'ipdconfig'
include Clockwork

handler { |job| Stalker.enqueue(job) }

every 1.hours, 'picture.report_new'
every 1.hours, 'user_requests.remove_stale'
every 1.hours, 'picture.complete_removal'
every 1.day, 'message.remove_old'
every 1.day, 'user_requests.remove_cleared'
