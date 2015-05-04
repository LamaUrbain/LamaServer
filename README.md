[![Build Status](https://travis-ci.org/LamaUrbain/LamaServer.png?branch=master)](https://travis-ci.org/LamaUrbain/LamaServer)

How to setup the database and build the project
===============================================

To init the database, just execute:
`
 $ sudo -u postgres psql -f createdb.sql
`
By default the password is 'lamaurbain', if you want to change it, then execute:
`
 $ sudo -u postgres psql
 postgres=# \password lamaurbain
 <type your password>
`
The final part is about to create a file named 'password' filled with the password you just gave,
and recompile the project with:
`
 $ make
`
Then either you can do:
`
 $ make install
`
and setuping your server or do:
`
 $ make run
`
for testing.
