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
  PICTURE_MAX_HORZ_SIZE = 800
  PICTURE_MAX_VERT_SIZE = 600
  COLORS = PATH + '/data/colors.txt'
  GROUP_NEGATIVE_DISPLAY_MOD = 0.04
  PICTURE_REMOVAL_GRACE_SPAN = 86400

  # User
  ADJECTIVES = PATH + '/data/adjectives.txt'
  NOUNS = PATH + '/data/nouns.txt'
  REQUEST_ACCEPT_SPAN = 172800
  EMAIL_USER_MGMT = 'me@indypicdump.com'
  TEMPLATE_DIR = PATH + '/templates'
  # list of nicks users may not have
  RESERVED_NICKS = PATH + '/data/reserved_nicks.txt'

  # Message
  MSG_SHOW_SPAN = 604800
  MSG = {
    1 => "You sent a duplicate picture",
    2 => "You posted to an unknown dump",
    3 => "The picture you sent was too small",
    4 => "You are no member of this dump",
    5 => "You sent a duplicate picture (in group)",
    6 => "You posted to an unknown dump (in group)",
    7 => "The picture you sent was too small (in group)",
    8 => "You are no member of this dump (in group)",
  }
  MSG_DUPLICATE_PICTURE = 1
  MSG_UNKNOWN_DUMP = 2
  MSG_PIC_TOO_SMALL = 3
  MSG_NO_DUMP_MEMBER = 4
  MSG_GROUP_DUPLICATE_PICTURE = 5
  MSG_GROUP_UNKNOWN_DUMP = 6
  MSG_GROUP_PIC_TOO_SMALL = 7
  MSG_GROUP_NO_DUMP_MEMBER = 8

  # Dump
  # list of names dumps may not have
  RESERVED_DUMPS = PATH + '/data/reserved_dumps.txt'
  DUMP_HONOR_TITLES = [
    "Grandmaster Dump %n",
    "%n, Knight of \"%d\"",
    "%n, Steel Panther",
    "%n, Pluto is a planet, dammit!",
    "%n, Little Miss Sunshine",
    "%n, Number of the Beast",
    "%n and the Bandit",
    "%n, Dances with Wolves",
    "%n, Apprentice of \"%d\"",
    "%i\"Redshirt\"",
  ]
  COOKIE_LIFETIME = 2678400

  # Misc
  REGEX_EMAIL = %q{[a-z0-9!#$\%&'*+/=?^_`{|}~-]+(?:\.[a-z0-9!#$\%&'*+/=?^_`{|}~-]+)*@(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+(?:[A-Z]{2}|com|org|net|edu|gov|mil|biz|info|mobi|name|aero|asia|jobs|museum)\b}
  # TODO
  # find length cap of first part of filename
  # and also supported picture extensions
  REGEX_FILENAME = %q{\d+\.(?:\d+\.)?[a-z]{3,4}}
end
