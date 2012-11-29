module IPDConfig
  # General
  DB = "/home/schommer/dev/indypicdump/horrible.db"
  DB_HANDLE = SQLite3::Database.new IPDConfig::DB
  HTTP_AUTH_USER = ""
  HTTP_AUTH_PASS = ""
  # Picture
  POP3_HOST = "pop.gmail.com"
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
