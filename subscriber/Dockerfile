FROM postgres:11.10

RUN apt-get update && apt-get install -y curl
RUN curl https://dl.2ndquadrant.com/default/release/get/deb | bash && apt-get update

### IMPORTANT: use 2.2.2 instead of 2.2.1! Otherwise PG 11.10 is very sad!
RUN apt-get install -y -V postgresql-${PG_MAJOR}-pglogical=2.2.2-1.stretch+1

# the following copied from https://github.com/reediculous456/docker-pglogical/blob/master/Dockerfile
RUN echo "wal_level = 'logical'" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "max_worker_processes = 10" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "max_replication_slots = 10" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "max_wal_senders = 10" >> /usr/share/postgresql/postgresql.conf.sample && \
    echo "shared_preload_libraries = 'pglogical'" >> /usr/share/postgresql/postgresql.conf.sample

RUN echo "host    replication          postgres                172.18.0.0/16   trust" >> /usr/share/postgresql/${PG_MAJOR}/pg_hba.conf.sample && \
    echo "host    replication          postgres                ::1/128         trust" >> /usr/share/postgresql/${PG_MAJOR}/pg_hba.conf.sample

# copy initial sql queries
COPY init.sql /docker-entrypoint-initdb.d/init.sql
