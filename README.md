# pglogical-poc

> Replicate from PostgreSQL 11.5 to 11.10 using pglogical 2.2.2

## Documentation

> Based on [pglogical-docs](https://www.2ndquadrant.com/en/resources/pglogical/pglogical-docs/)

The pglogical extension provides logical streaming replication for PostgreSQL, using a publish/subscribe module. We use the following terms to describe data streams between nodes:

- _Nodes_: PostgreSQL database instances
- _Providers and Subscribers_: Roles taken by nodes
- _Replication Set_: A collection of tables

Use cases supported are:

- Upgrades between major versions
- Full database replication
- Selective replication of sets of tables using replication sets
- Selective replication of table rows at either publisher or subscriber side (`row_filter`)
- Selective replication of table columns at publisher side
- Data gather/merge from multiple upstream servers

Architectural details:

- pglogical works on a per-database level, not whole server level like physical streaming replication
- One provider may feed multiple subscribers without incurring additional disk write overhead
- One subscriber can merge changes from several origins and detect conflict between changes with automatic and configurable conflict resolution
- Cascading replication is implemented in the form of changeset forwarding

### Requirements

To use pglogical the provider and subscriber must be running PostgreSQL 9.4 or newer. The `pglogical` extension must be installed on both provider and subscriber. You must `CREATE EXTENSION pglogical` on both. Tables on the provider and subscriber must have the same names and be in the same schema. Tables on the provider and subscriber must have the same columns, with the same data types in each column. `CHECK` constraints, `NOT NULL` constraints, etc. must be the same or weaker (more permissive) on the subscriber than the provider. Tables must have the same `PRIMARY KEY`s. It is not recommended to add additional `UNIQUE` constraints other than the `PRIMARY KEY`.

### Usage

First the PostgreSQL server has to be properly configured to support logical decoding:

```conf
wal_level = 'logical'
# one per database needed on provider node
# one per node needed on subscriber node
max_worker_processes = 10
# one per node needed on provider node
max_replication_slots = 10
# one per node needed on provider node
max_wal_senders = 10
shared_preload_libraries = 'pglogical'
```

`pg_hba.conf` has to allow replication connections from `localhost`.

Next the `pglogical` extension has to be installed on all nodes:

```sql
CREATE EXTENSION pglogical;
```

Now create the provider node:

```sql
SELECT pglogical.create_node(
  node_name := 'provider1',
  dsn := 'host=providerhost port=5432 dbname=db'
);
```

Add all tables in `public` schema to the `default` replication set.

```sql
SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);
```

Optionally you can also create additional replication sets and add tables to them. It’s usually better to create replication sets before subscribing so that all tables are synchronized during initial replication setup in a single initial transaction. However, users of bigger databases may instead wish to create them incrementally for better control.

Once the provider node is setup, subscribers can be subscribed to it. First the subscriber node must be created:

```sql
SELECT pglogical.create_node(
  node_name := 'subscriber1',
  dsn := 'host=subscriberhost port=5432 dbname=db'
);
```

And finally on the subscriber node you can create the subscription which will start synchronization and replication process in the background:

```sql
SELECT pglogical.create_subscription(
  subscription_name := 'subscription1',
  provider_dsn := 'host=providerhost port=5432 dbname=db'
);
```

Replication sets provide a mechanism to control which tables in the database will be replicated and which actions on those tables will be replicated. Each replicated set can specify individually if `INSERT`s, `UPDATE`s, `DELETE`s and `TRUCATE`s on the set are replicated. Every table can be in multiple replication sets and every subscriber can subscribe to multiple replication sets as well. The resulting set of tables and actions replicated is the union of the sets the table is in. The tables are not replicated until they are added into a replication set.

### Row based filtering

```sql
SELECT pglogical.replication_set_add_table(
  set_name := 'default',
  relation := 'public.spaces',
  row_filter := 'SELECT * FROM public.spaces WHERE space_id = 1'
);
```

## Setup

In this PoC we logically replicate from a PostgreSQL 11.5 to a PostgreSQL 11.10. Both instances running in Docker containers and communicating with each other. Both have pglogical 2.2.2 installed.

```bash
# start containers
docker-compose up -d

# in case we need to rebuilt the images use
docker-compose up -d --build

# running services
docker-compose ps

# stop containers
docker-compose down --rmi all
```

## Manual

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

## Resources

- [PostgreSQL and the logical replication](https://blog.raveland.org/post/postgresql_lr_en/)
- [PostgreSQL replication with Docker](https://medium.com/swlh/postgresql-replication-with-docker-c6a904becf77)
- [Dockerfile](https://gist.github.com/asaaki/b07dccfd6ff6eed4c7b4ef279ade7b0c)
- [docker-pglogical](https://github.com/reediculous456/docker-pglogical/blob/master/Dockerfile)
- [Demystifying pglogical](http://thedumbtechguy.blogspot.com/2017/04/demystifying-pglogical-tutorial.html)
- [Short tutorial to setup replication using pglogical](https://gist.github.com/ratnakri/c22a7389d9fab788d7b8b12e2a6c337a)
- [How to configure pglogical](https://www.tutorialdba.com/2018/01/how-to-configure-pglogical-streaming.html)
- [PostgreSQL – logical replication with pglogical](https://blog.dbi-services.com/postgresql-logical-replication-with-pglogical/)
- [PG Phriday: Perfectly Logical](http://bonesmoses.org/2016/10/14/pg-phriday-perfectly-logical/)
