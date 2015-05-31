SET client_encoding = 'UTF8';

CREATE USER lamaurbain PASSWORD 'lamaurbain';
CREATE DATABASE lamaurbain OWNER lamaurbain ENCODING 'UTF8';
\connect lamaurbain

CREATE DOMAIN dom_name TEXT CHECK (
  LENGTH(VALUE) > 1 AND
  LENGTH(VALUE) < 200
);

CREATE DOMAIN dom_mail TEXT CHECK (
  LENGTH(VALUE) > 3 AND
  LENGTH(VALUE) < 254
);

CREATE DOMAIN dom_username TEXT CHECK (
  LENGTH(VALUE) < 100
);

CREATE TABLE users_table (
  username dom_username NOT NULL,
  password text NOT NULL,
  email dom_mail NOT NULL,
  id integer PRIMARY KEY,
  created date NOT NULL default CURRENT_DATE
);

ALTER TABLE users_table OWNER TO lamaurbain;

CREATE TABLE auth_table (
  token text NOT NULL PRIMARY KEY,
  owner integer NOT NULL,
  created date NOT NULL default CURRENT_DATE,
);

CREATE TABLE coord_table (
  id integer PRIMARY KEY,
  latitude real NOT NULL,
  longitude real NOT NULL,
  created date NOT NULL default CURRENT_DATE,
  address text
);

CREATE TABLE itinerary_table (
  id integer PRIMARY KEY,
  owner integer,
  name dom_name,
  favorite boolean,
  departure int NOT NULL,
  created date NOT NULL default CURRENT_DATE,
  destinations int[]
);

CREATE SEQUENCE users_id_seq;
ALTER SEQUENCE users_id_seq OWNER TO lamaurbain;
