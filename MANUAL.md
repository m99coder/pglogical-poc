# Manual Setup

> Manually setup logical replication based on [PostgreSQL and the logical replication](https://blog.raveland.org/post/postgresql_lr_en/)

```bash
# setup
docker network create pg-network
docker container run -d \
  --name pgprovider --network pg-network \
  -e POSTGRES_PASSWORD=password \
  postgres:11.5-alpine
docker container run -d \
  --name pgsubscriber --network pg-network \
  -e POSTGRES_PASSWORD=password \
  postgres:11.10-alpine
```

```bash
# configure WAL level
docker container exec -it pgprovider /bin/sh
/ # psql -U postgres
psql (11.5)
Type "help" for help.

postgres=# ALTER SYSTEM SET wal_level = 'logical';
ALTER SYSTEM
postgres=# SHOW wal_level;
 wal_level
-----------
 replica
(1 row)

postgres=# exit
/ # exit
docker container restart pgprovider
```

```bash
# create a database and a table with dummy data
# create a role, a publication and grant access for role
docker container exec -it pgprovider /bin/sh
/ # psql -U postgres
psql (11.5)
Type "help" for help.

postgres=# CREATE DATABASE replication;
CREATE DATABASE
postgres=# \c replication
You are now connected to database "replication" as user "postgres".
replication=# CREATE TABLE hashes (id SERIAL, value CHAR(33), PRIMARY KEY(value));
CREATE TABLE
replication=# INSERT INTO hashes (SELECT generate_series(1, 1000), md5(random()::text));
INSERT 0 1000
replication=# CREATE ROLE replicate WITH LOGIN PASSWORD 'qwertz' REPLICATION;
CREATE ROLE
replication=# CREATE PUBLICATION pubhashes FOR TABLE hashes;
CREATE PUBLICATION
replication=# GRANT SELECT ON hashes TO replicate;
GRANT
replication=# exit
/ # exit
```

```bash
# create a database and a table
# create a subscription
docker container exec -it pgsubscriber /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# CREATE DATABASE replication_repl;
CREATE DATABASE
postgres=# \c replication_repl
You are now connected to database "replication_repl" as user "postgres".
replication_repl=# CREATE TABLE hashes (id SERIAL, value CHAR(33), PRIMARY KEY(value));
CREATE TABLE
replication_repl=# CREATE SUBSCRIPTION subhashes CONNECTION 'host=pgprovider dbname=replication user=replicate password=qwertz' PUBLICATION
pubhashes;
NOTICE:  created replication slot "subhashes" on publisher
CREATE SUBSCRIPTION
replication_repl=# exit
/ # exit
```

```bash
# view logs
docker container logs pgsubscriber
2021-03-16 11:26:32.363 UTC [75] LOG:  logical replication apply worker for subscription "subhashes" has started
2021-03-16 11:26:32.370 UTC [76] LOG:  logical replication table synchronization worker for subscription "subhashes", table "hashes" has started
2021-03-16 11:26:32.395 UTC [76] LOG:  logical replication table synchronization worker for subscription "subhashes", table "hashes" has finished
```

```bash
# count replicated data
docker container exec -it pgsubscriber /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication_repl
You are now connected to database "replication_repl" as user "postgres".
replication_repl=# SELECT COUNT(*) FROM hashes;
 count
-------
  1000
(1 row)

replication_repl=# exit
/ # exit
```

```bash
# alter table for pgprovider
docker container exec -it pgprovider /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication
You are now connected to database "replication" as user "postgres".
replication_repl=# ALTER TABLE hashes ADD COLUMN gold BOOLEAN DEFAULT false;
ALTER TABLE
replication=# DELETE FROM hashes;
DELETE 1000
replication=# exit
/ # exit
```

```bash
# logs for pgprovider
2021-03-16 13:06:09.027 UTC [65] LOG:  could not send data to client: Connection reset by peer
2021-03-16 13:06:09.027 UTC [65] CONTEXT:  slot "subhashes", output plugin "pgoutput", in the change callback, associated LSN 0/16C1160

# logs for pgsubscriber
2021-03-16 13:06:29.083 UTC [96] ERROR:  logical replication target relation "public.hashes" is missing some replicated columns
```

```bash
# alter table for pgsubscriber
docker container exec -it pgsubscriber /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication_repl
You are now connected to database "replication_repl" as user "postgres".
replication_repl=# ALTER TABLE hashes ADD COLUMN gold BOOLEAN DEFAULT false;
ALTER TABLE
replication_repl=# exit
/ # exit
```

```bash
# add table, insert some data and update the publication
docker container exec -it pgprovider /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication
You are now connected to database "replication" as user "postgres".
replication=# CREATE TABLE hash2hash (id SERIAL, value CHAR(33), PRIMARY KEY(value));
CREATE TABLE
replication=# GRANT SELECT ON hash2hash TO replicate;
GRANT
replication=# INSERT INTO hash2hash (SELECT generate_series(1, 1000), md5(md5(random()::text)));
INSERT 0 1000
replication=# ALTER PUBLICATION pubhashes ADD TABLE hash2hash;
ALTER PUBLICATION
replication=# exit
/ # exit
```

```bash
# add table and refresh subscription
docker container exec -it pgsubscriber /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication_repl
You are now connected to database "replication_repl" as user "postgres".
replication_repl=# CREATE TABLE hash2hash (id SERIAL, value CHAR(33), PRIMARY KEY(value));
CREATE TABLE
replication_repl=# ALTER SUBSCRIPTION subhashes REFRESH PUBLICATION;
ALTER SUBSCRIPTION
replication_repl=# exit
/ # exit
```

```bash
# logs for pgsubscriber
2021-03-16 13:13:53.101 UTC [137] LOG:  logical replication table synchronization worker for subscription "subhashes", table "hash2hash" has started
2021-03-16 13:13:53.128 UTC [137] LOG:  logical replication table synchronization worker for subscription "subhashes", table "hash2hash" has finished
```

```bash
# add table and refresh subscription
docker container exec -it pgsubscriber /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication_repl
You are now connected to database "replication_repl" as user "postgres".
replication_repl=# SELECT COUNT(*) FROM hash2hash;
 count
-------
  1000
(1 row)

replication_repl=# exit
/ # exit
```

```bash
# stop logical replication for pgsubscriber
docker container exec -it pgsubscriber /bin/sh
/ # psql -U postgres
psql (11.10)
Type "help" for help.

postgres=# \c replication_repl
You are now connected to database "replication_repl" as user "postgres".
replication_repl=# ALTER SUBSCRIPTION subhashes DISABLE;
ALTER SUBSCRIPTION
replication_repl=# DROP SUBSCRIPTION subhashes;
NOTICE:  dropped replication slot "subhashes" on publisher
DROP SUBSCRIPTION
replication_repl=# exit
/ # exit
```

```bash
# logs for pgsubscriber
2021-03-16 13:16:04.824 UTC [125] LOG:  logical replication apply worker for subscription "subhashes" will stop because the subscription was disabled
```

```bash
# cleanup
docker stop pgsubscriber && docker rm pgsubscriber
docker stop pgprovider && docker rm pgprovider
docker network rm pg-network
```
