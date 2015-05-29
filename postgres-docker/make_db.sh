#!/bin/bash
echo "******CREATING DOCKER DATABASE******"

echo "starting postgres"
gosu postgres pg_ctl -w start

gosu postgres psql -h localhost -p 5432 -U postgres -a -f /db/createdb.sql

echo "stopping postgres"
gosu postgres pg_ctl stop

echo "stopped postgres"


echo ""
echo "******DOCKER DATABASE CREATED******"
