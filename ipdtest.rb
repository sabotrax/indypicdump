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

require 'mail'

class IPDTest
  def self.gen_mail
    Mail.defaults do
      delivery_method :test
    end
    mail = Mail.new do
      from	"Marcus <backflip@indypicdump.com>"
      to	"receiver@indypicdump.com"
      subject	"this is a test"
      add_file 	"test/golden_gate_test.jpg"
    end
    mail.deliver
    Mail::TestMailer.deliveries.first
  end
end
