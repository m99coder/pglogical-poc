FROM postgres:11.10

# add apt-archive repository
RUN echo "deb https://apt-archive.postgresql.org/pub/repos/apt stretch-pgdg-archive main\ndeb-src https://apt-archive.postgresql.org/pub/repos/apt stretch-pgdg-archive main" > /etc/apt/sources.list.d/pgdg.list
RUN apt-get update || true && \
  apt-get install -y apt-transport-https && \
  apt-get update && \
  apt-get install -y curl

RUN curl https://dl.2ndquadrant.com/default/release/get/deb | bash && apt-get update

### IMPORTANT: use 2.2.2 instead of 2.2.1! Otherwise PG 11.10 is very sad!
RUN apt-get install -y -V postgresql-${PG_MAJOR}-pglogical=2.2.2-1.stretch+1

# copy sql queries
COPY init.sql /docker-entrypoint-initdb.d/init.sql
COPY migration.sql /migration.sql
COPY migration-2.sql /migration-2.sql
COPY replication.sql /replication.sql
COPY create-subscription.sql /create-subscription.sql
COPY drop-subscription.sql /drop-subscription.sql
