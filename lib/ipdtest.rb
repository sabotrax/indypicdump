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

require 'mail'

class IPDTest
  def self.gen_mail
    Mail.defaults do
      delivery_method :test
    end
    mail = Mail.new do
      from	"schommer@localhost"
      to	"me@indypicdump.com"
      subject	"stats please"
      #body	"http://172.16.2.36/picture/show/detail/1431435524.0642946.jpg"
      #add_file 	"#{File.dirname(__FILE__)}/../test/marta1.jpg"
    end
    mail.deliver
    Mail::TestMailer.deliveries.first
  end

  # needs
  # - initial length of array
  # - array
  def self.random_distribution(le, arr)
    count = {}
    arr.each do |i|
      if count.has_key?(i)
	count[i] += 1
      else
	count[i] = 0
      end
    end
    percent = {}
    count.each_key do |k|
      percent[k] = (count[k].to_f / le.to_f).to_f * 100
    end
    return percent
  end
end
