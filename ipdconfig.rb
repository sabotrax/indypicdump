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

module IPDConfig
  # General
  PATH = '/home/schommer/dev/indypicdump'
  DB = PATH + '/horrible.db'
  DB_HANDLE = SQLite3::Database.new DB
  LOG = PATH + '/log/indypicdump.log'
  LOG_ROTATION = 'daily'
  # 0 = debug
  # 1 = info
  # 2 = warn
  LOG_LEVEL = 0
  HTTP_AUTH_USER = ''
  HTTP_AUTH_PASS = ''
  # Picture
  POP3_HOST = ''
  POP3_PORT = 995
  POP3_USER = ''
  POP3_PASS = ''
  FETCH_MAILS = 5
  TMP_DIR = PATH + '/tmp'
  PIC_DIR = PATH + '/pics'
  GEN_RANDOM_IDS = 100
  NOSHOW_LAST_IDS = 5
  CLIENT_TIMEOUT = 300
  # User
  ADJECTIVES = PATH + '/data/adjectives.txt'
  NOUNS = PATH + '/data/nouns.txt'
end
