FROM postgres:15.2

RUN apt-get update && apt-get install -y curl
RUN curl https://techsupport.enterprisedb.com/api/repository/dl/default/release/deb | bash && apt-get update

RUN apt-get install -y -V postgresql-${PG_MAJOR}-pglogical

# copy sql queries
COPY init.sql /docker-entrypoint-initdb.d/init.sql
COPY migration.sql /migration.sql
COPY migration-2.sql /migration-2.sql
COPY replication.sql /replication.sql
COPY create-subscription.sql /create-subscription.sql
COPY drop-subscription.sql /drop-subscription.sql
