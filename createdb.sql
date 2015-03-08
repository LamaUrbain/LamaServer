GRANT ALL PRIVILEGES ON DATABASE lamaurbain TO lamaurbain;
SET client_encoding = 'UTF8';

CREATE TABLE users_table (
  username text NOT NULL,
  password text NOT NULL,
  email text NOT NULL,
  id integer PRIMARY KEY
);

CREATE SEQUENCE users_id_seq;
