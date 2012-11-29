CREATE TABLE email_address(id integer primary key autoincrement, address text, time_created int);
CREATE TABLE mapping_user_email_address(id_user int , id_address int);
CREATE TABLE picture(id integer primary key autoincrement, filename text, time_taken int, time_send int, id_user int);
CREATE TABLE user(id integer primary key autoincrement, nick text, time_created int);
