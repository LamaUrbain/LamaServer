SET client_encoding = 'UTF8';

CREATE USER lamaurbain PASSWORD 'lamaurbain';
CREATE DATABASE lamaurbain OWNER lamaurbain ENCODING 'UTF8';
\connect lamaurbain

CREATE DOMAIN dom_name TEXT CHECK (
  LENGTH(VALUE) > 1 AND
  LENGTH(VALUE) < 200
);
ALTER DOMAIN dom_name OWNER TO lamaurbain;

CREATE DOMAIN dom_mail TEXT CHECK (
  LENGTH(VALUE) > 3 AND
  LENGTH(VALUE) < 254
);
ALTER DOMAIN dom_mail OWNER TO lamaurbain;

CREATE DOMAIN dom_username TEXT CHECK (
  LENGTH(VALUE) < 100
);
ALTER DOMAIN dom_username OWNER TO lamaurbain;

CREATE TABLE users_table (
  username dom_username NOT NULL,
  password text NOT NULL,
  email dom_mail NOT NULL,
  id integer PRIMARY KEY,
  sponsor boolean NOT NULL,
  created timestamp NOT NULL default CURRENT_timestamp,
  UNIQUE(username)
);
ALTER TABLE users_table OWNER TO lamaurbain;

CREATE SEQUENCE users_id_seq;
ALTER SEQUENCE users_id_seq OWNER TO lamaurbain;

CREATE TABLE auth_table (
  token text NOT NULL PRIMARY KEY,
  owner text NOT NULL,
  created timestamp NOT NULL DEFAULT CURRENT_timestamp
);
ALTER TABLE auth_table OWNER TO lamaurbain;

CREATE TABLE coords_table (
  id integer PRIMARY KEY,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  address text
);
ALTER TABLE coords_table OWNER TO lamaurbain;

CREATE SEQUENCE coords_id_seq;
ALTER SEQUENCE coords_id_seq OWNER TO lamaurbain;

CREATE TABLE itineraries_table (
  id integer PRIMARY KEY,
  owner text,
  name dom_name,
  favorite boolean,
  departure integer NOT NULL REFERENCES coords_table ON DELETE CASCADE,
  creation timestamp NOT NULL,
  destinations integer[] NOT NULL, -- REFERENCES coords_table ON DELETE CASCADE
  vehicle integer NOT NULL
);
ALTER TABLE itineraries_table OWNER TO lamaurbain;

CREATE SEQUENCE itineraries_id_seq;
ALTER SEQUENCE itineraries_id_seq OWNER TO lamaurbain;

CREATE TABLE incidents_table (
  id integer PRIMARY KEY,
  name dom_name,
  begin_ timestamp NOT NULL default CURRENT_timestamp,
  end_ timestamp NOT NULL,
  position integer NOT NULL REFERENCES coords_table ON DELETE CASCADE
);

ALTER TABLE incidents_table OWNER TO lamaurbain;

CREATE SEQUENCE incidents_id_seq;
ALTER SEQUENCE incidents_id_seq OWNER TO lamaurbain;
