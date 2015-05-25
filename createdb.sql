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

CREATE TABLE auth_table (
  token text NOT NULL,
  owner integer NOT NULL,
  PRIMARY KEY token
);

CREATE TABLE coord_table (
  id integer PRIMARY KEY,
  latitude real NOT NULL,
  longitude real NOT NULL,
  address text
);

CREATE TABLE itinerary_table (
  id integer PRIMARY KEY,
  owner integer,
  name text,
  favorite boolean,
  departure int NOT NULL,
  destinations int[]
);

CREATE SEQUENCE users_id_seq;
ALTER SEQUENCE users_id_seq OWNER TO lamaurbain;
