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
      from	"root@indypicdump.com"
      to	"foo@indypicdump.com"
      subject	"some"
      #add_file 	"test/farben_test.jpg"
      add_file 	"test/summer_test.jpg"
      #add_file 	"test/beach_test.jpg"
      #add_file 	"test/snowboard_animated_test.gif"
      #add_file 	"test/static_test.gif"
      #add_file 	"test/jungfernstieg_test.jpg"
      #add_file 	"test/hypnotoad_test.gif"
      #add_file 	"test/silvi_test.jpg"
      #add_file 	"test/vegetarians-test.gif"
      #add_file 	"test/daffodils_test.jpg"
      #add_file 	"test/volvic_too_small_test.jpg"
      #add_file 	"test/die_w_70er_test.jpg"
      #add_file 	"test/han_solo_test.jpg"
      #add_file 	"test/northern_darkness_cat_test.jpg"
      #add_file 	"test/angus_test.jpg"
      #add_file 	"test/schuler_test.jpg"
      #add_file 	"test/computer_test.jpg"
      #add_file 	"test/golden_gate_test.jpg"
      #add_file 	"test/fountain_test_w_exif_date_broken.jpg"
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
