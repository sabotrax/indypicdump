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

class IPDError < StandardError; end

class IPDPictureError < IPDError; end
class DumpEmpty < IPDPictureError; end
class BadLuck < IPDPictureError; end
class PictureMissing < IPDPictureError; end

class IPDDumpError < IPDError; end

class IPDUserError < IPDError; end

class IPDRequestError < IPDError; end

class IPDMessageError < IPDError; end
