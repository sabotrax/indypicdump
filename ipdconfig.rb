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

require 'logger'

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
  LOG_HANDLE = Logger.new(LOG, LOG_ROTATION)
  LOG_HANDLE.level = LOG_LEVEL
  HTTP_AUTH_USER = ''
  HTTP_AUTH_PASS = ''
  RENDER_PRETTY = true
  ENVIRONMENT = :development
  RECAPTCHA_PUB_KEY = ''
  RECAPTCHA_PRIV_KEY = ''
  EMAIL_SELF = 'busybee@indypicdump.com'
  EMAIL_OPERATOR = ''

  # Picture
  POP3_HOST = 'localhost'
  POP3_PORT = 110
  POP3_USER = ''
  POP3_PASS = ''
  POP3_SSL = false
  FETCH_MAILS = 5
  TMP_DIR = PATH + '/tmp'
  PIC_DIR = PATH + '/pics'
  GEN_RANDOM_IDS = 200
  NOSHOW_LAST_IDS = 8
  CLIENT_TIMEOUT = 300
  PIC_DISPLAY_MOD_SPAN = 259200
  PIC_DISPLAY_MOD = 0.07
  PIC_MIN_SIZE = 400
  REPORT_NEW_TIMER = 3600

  # User
  ADJECTIVES = PATH + '/data/adjectives.txt'
  NOUNS = PATH + '/data/nouns.txt'

  # Message
  MSG_SHOW_SPAN = 604800
  MSG = {
    1 => "You sent a duplicate picture",
    2 => "You posted to an unknown dump",
    3 => "The picture you sent was too small",
  }
  MSG_DUPLICATE_PIC = 1
  MSG_UNKNOWN_DUMP = 2
  MSG_PIC_TOO_SMALL = 3

  # Dump
  # list of names dumps may not have
  RESERVED = PATH + '/data/reserved.txt'
end
