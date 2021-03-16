FROM postgres:11.5

RUN apt-get update && apt-get install -y curl
RUN curl https://dl.2ndquadrant.com/default/release/get/deb | bash && apt-get update

### IMPORTANT: use 2.2.2 instead of 2.2.1! Otherwise PG 11.5 is very sad!
RUN apt-get install -y -V postgresql-${PG_MAJOR}-pglogical=2.2.2-1.stretch+1

# copy initial sql queries
COPY init.sql /docker-entrypoint-initdb.d/init.sql