CREATE DATABASE lamaurbain;
CREATE USER lamaurbain PASSWORD 'lamaurbain';

\connect lamaurbain

GRANT ALL PRIVILEGES ON DATABASE lamaurbain TO lamaurbain;
SET client_encoding = 'UTF8';

CREATE TABLE users_table (
  username text NOT NULL,
  password text NOT NULL,
  email text NOT NULL,
  id integer PRIMARY KEY
);
GRANT ALL PRIVILEGES ON users_table TO lamaurbain;

CREATE SEQUENCE users_id_seq;
GRANT ALL PRIVILEGES ON users_id_seq TO lamaurbain;
