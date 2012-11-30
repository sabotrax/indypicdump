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
  TMP_DIR = "/home/schommer/dev/indypicdump/tmp"
  PIC_DIR = "/home/schommer/dev/indypicdump/pics"
  GEN_RANDOM_IDS = 100
  # User
  ADJECTIVES = "/home/schommer/dev/indypicdump/data/adjectives.txt"
  NOUNS = "/home/schommer/dev/indypicdump/data/nouns.txt"
end
