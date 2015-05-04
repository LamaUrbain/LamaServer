SET client_encoding = 'UTF8';

CREATE USER lamaurbain PASSWORD 'lamaurbain';
CREATE DATABASE lamaurbain OWNER lamaurbain ENCODING 'UTF8';
\connect lamaurbain

CREATE TABLE users_table (
  username text NOT NULL,
  password text NOT NULL,
  email text NOT NULL,
  id integer PRIMARY KEY
);
ALTER TABLE users_table OWNER TO lamaurbain;

CREATE SEQUENCE users_id_seq;
ALTER SEQUENCE users_id_seq OWNER TO lamaurbain;
