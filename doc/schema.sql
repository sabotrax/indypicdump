CREATE TABLE dump(id integer primary key autoincrement, alias text, time_created int, state text, password text);
CREATE TABLE email_address(id integer primary key autoincrement, address text, time_created int);
CREATE TABLE mapping_dump_user(id_dump int, id_user int, admin int, time_created int);
CREATE TABLE mapping_user_email_address(id_user int , id_address int);
CREATE TABLE message(id integer primary key autoincrement, message_id int, time_created int, id_user int);
CREATE TABLE "picture" (id integer primary key autoincrement, filename text, time_taken int, time_sent int, id_user int, original_hash text, id_dump int, path text, precursor int, successor int, no_show int);
CREATE TABLE picture_common_color (id_picture integer primary key, color text);
CREATE TABLE user(id integer primary key autoincrement, nick text, time_created int, accept_external_messages int);
CREATE TABLE user_request (id integer primary key autoincrement, action text, code text, time_created int);
