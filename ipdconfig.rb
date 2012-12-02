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

module IPDConfig
  # General
  DB = "/home/schommer/dev/indypicdump/horrible.db"
  DB_HANDLE = SQLite3::Database.new IPDConfig::DB
  LOG = "/home/schommer/dev/indypicdump/log/indypicdump.log"
  LOG_ROTATION = "daily"
  # 0 = debug
  # 1 = info
  # 2 = warn
  LOG_LEVEL = 0
  HTTP_AUTH_USER = ""
  HTTP_AUTH_PASS = ""
  # Picture
  POP3_HOST = ""
  POP3_PORT = 995
  POP3_USER = ""
  POP3_PASS = ""
  FETCH_MAILS = 5
  TMP_DIR = "/home/schommer/dev/indypicdump/tmp"
  PIC_DIR = "/home/schommer/dev/indypicdump/pics"
  GEN_RANDOM_IDS = 100
  NOSHOW_LAST_IDS = 5
  CLIENT_TIMEOUT = 300
  # User
  ADJECTIVES = "/home/schommer/dev/indypicdump/data/adjectives.txt"
  NOUNS = "/home/schommer/dev/indypicdump/data/nouns.txt"
end
