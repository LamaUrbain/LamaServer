[![Build Status](https://travis-ci.org/LamaUrbain/LamaServer.png?branch=master)](https://travis-ci.org/LamaUrbain/LamaServer)

How to setup the database and build the project
===============================================

To init the database, just execute:

`
 $ sudo -u postgres psql -f postgres-docker/createdb.sql
`

By default the password is 'lamaurbain', if you want to change it, then execute:

`
 $ sudo -u postgres psql
 postgres=# \password lamaurbain
 <type your password>
`

The final part is about creating a file named 'password' filled with the password you just gave.
Then correct the file db_macaque_wrapper.ml with the address on which the database is located.

After that you can use Docker to build the project's image
`
 $ docker build -t lamaserver
`

And then run it using this command
`
 $ docker run -p 0.0.0.0:8080:8080 -t lamaserver
`

