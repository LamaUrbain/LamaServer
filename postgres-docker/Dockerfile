FROM postgres

RUN mkdir -p /var/lib/pgdata
ENV PGDATA /var/lib/pgdata
ADD createdb.sql /db/
ADD make_db.sh /docker-entrypoint-initdb.d/
