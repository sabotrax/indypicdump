CREATE TABLE dump(id integer primary key autoincrement, alias text, time_created int);
CREATE TABLE email_address(id integer primary key autoincrement, address text, time_created int);
CREATE TABLE mapping_user_email_address(id_user int , id_address int);
CREATE TABLE message(id integer primary key autoincrement, message_id int, time_created int, id_user int);
CREATE TABLE picture(id integer primary key autoincrement, filename text, time_taken int, time_send int, id_user int, original_hash text, id_dump int, path text);
CREATE TABLE user(id integer primary key autoincrement, nick text, time_created int);
