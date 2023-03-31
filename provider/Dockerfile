FROM postgres:14.7

RUN apt-get update && apt-get install -y curl
RUN curl https://techsupport.enterprisedb.com/api/repository/dl/default/release/deb | bash && apt-get update

RUN apt-get install -y -V postgresql-${PG_MAJOR}-pglogical

# copy sql queries
COPY init.sql /docker-entrypoint-initdb.d/init.sql
COPY migration.sql /migration.sql
COPY migration-2.sql /migration-2.sql
COPY backfill.sql /backfill.sql
COPY replication.sql /replication.sql
COPY create-replication-set.sql /create-replication-set.sql
COPY drop-replication-set.sql /drop-replication-set.sql
COPY pgbench.sql /pgbench.sql
