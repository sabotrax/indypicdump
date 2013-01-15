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
require 'sqlite3'

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
  PICTURE_DIR = PATH + '/pics'
  GEN_RANDOM_IDS = 200
  NOSHOW_LAST_IDS = 8
  CLIENT_TIMEOUT = 300
  PICTURE_DISPLAY_MOD_SPAN = 259200
  PICTURE_DISPLAY_MOD = 0.07
  PICTURE_MIN_SIZE = 400
  REPORT_NEW_TIMER = 3600

  # User
  ADJECTIVES = PATH + '/data/adjectives.txt'
  NOUNS = PATH + '/data/nouns.txt'
  REQUEST_ACCEPT_SPAN = 172800
  EMAIL_USER_MGMT = 'me@indypicdump.com'
  TEMPLATE_DIR = PATH + '/templates'

  # Message
  MSG_SHOW_SPAN = 604800
  MSG = {
    1 => "You sent a duplicate picture",
    2 => "You posted to an unknown dump",
    3 => "The picture you sent was too small",
    4 => "You are no member of this dump"
  }
  MSG_DUPLICATE_PICTURE = 1
  MSG_UNKNOWN_DUMP = 2
  MSG_PIC_TOO_SMALL = 3
  MSG_NO_DUMP_MEMBER = 4

  # Dump
  # list of names dumps may not have
  RESERVED = PATH + '/data/reserved.txt'

  # Misc
  REGEX_EMAIL = %q{[a-z0-9!#$\%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$\%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|asia|jobs|museum)\b}
end
