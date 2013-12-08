# delete tables
DROP TABLE comments, 
signatures,
types,
sig_name ;


#Schema setup

CREATE TABLE sig_name (
id INT NOT NULL AUTO_INCREMENT ,
sig_name VARCHAR ( 64 ) UNIQUE NOT NULL ,
PRIMARY KEY ( id )
);


CREATE TABLE types(
id INT NOT NULL AUTO_INCREMENT ,
sig_type VARCHAR ( 24 ) UNIQUE NOT NULL ,
PRIMARY KEY ( id )
);


CREATE TABLE signatures(
sig_id INT ,
INDEX ( sig_id ) ,
FOREIGN KEY ( sig_id ) REFERENCES sig_name ( id ) ON UPDATE CASCADE ON DELETE CASCADE ,
sig_type_id INT ,
INDEX ( sig_type_id ) ,
FOREIGN KEY ( sig_type_id ) REFERENCES types ( id ) ON UPDATE CASCADE ON DELETE CASCADE ,
sig_text text NOT NULL ,
reference text ,
status ENUM('enabled', 'disabled', 'testing') ,
modified TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);


CREATE TABLE comments(
sig_id INT ,
INDEX ( sig_id ) ,
FOREIGN KEY ( sig_id ) REFERENCES sig_name ( id ) ON UPDATE CASCADE ON DELETE CASCADE ,
comment text ,
ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);



