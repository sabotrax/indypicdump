# This file is part of indypicdump.

# Foobar is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# Foobar is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

# Copyright 2012 Marcus Schommer <sabotrax@gmail.com>

require "mail"

class IPDTest
  def self.gen_mail
    Mail.new do
      from	"Marcus <zappo@indypicdump.com>"
      to	"receiver@indypicdump.com"
      subject	"this is a test"
      add_file 	"test/golden_gate_test.jpg"
    end
  end
end
