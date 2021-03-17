# pglogical-poc

> Replicate from PostgreSQL 11.5 to 11.10 using pglogical 2.2.2

> :warning: **Work in progress**

- [Manually setting up built-in logical replication](MANUAL.md)
- [Docker Compose Network checks](NETWORK.md)
- [pglogical-docs](PGLOGICAL.md)

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

Now create node and subscription manually for `pgsubscriber`.

```bash
docker exec -it pglogical-poc_pgsubscriber_1 psql -U postgres
psql (11.10 (Debian 11.10-1.pgdg90+1))
Type "help" for help.

postgres=# \c pg_logical_replication_results
You are now connected to database "pg_logical_replication_results" as user "postgres".
pg_logical_replication_results=# \dx
                   List of installed extensions
   Name    | Version |   Schema   |          Description
-----------+---------+------------+--------------------------------
 pglogical | 2.2.2   | pglogical  | PostgreSQL Logical Replication
 plpgsql   | 1.0     | pg_catalog | PL/pgSQL procedural language
(2 rows)

pg_logical_replication_results=# SELECT pglogical.create_node(
pg_logical_replication_results(#   node_name := 'subscriber',
pg_logical_replication_results(#   dsn := 'host=pgsubscriber port=5432 dbname=pg_logical_replication_results user=postgres password=s3cr3t'
pg_logical_replication_results(# );
 create_node
-------------
  2941155235
(1 row)

pg_logical_replication_results=# SELECT pglogical.create_subscription(
pg_logical_replication_results(#   subscription_name := 'subscription',
pg_logical_replication_results(#   replication_sets := array['hashes'],
pg_logical_replication_results(#   provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
pg_logical_replication_results(# );
 create_subscription
---------------------
          2875150205
(1 row)

pg_logical_replication_results=# SELECT COUNT(*) FROM hashes;
 count
-------
  1000
(1 row)

pg_logical_replication_results=# exit
```

Finally insert new hashes into `pgprovider` and check replication in `pgsubscriber`.

```bash
docker exec -it pglogical-poc_pgprovider_1 psql -U postgres
psql (11.5 (Debian 11.5-3.pgdg90+1))
Type "help" for help.

postgres=# \c pg_logical_replication
You are now connected to database "pg_logical_replication" as user "postgres".
pg_logical_replication=# INSERT INTO hashes (SELECT generate_series(1, 1000), md5(random()::TEXT));
INSERT 0 1000
pg_logical_replication=# exit
```

```bash
docker exec -it pglogical-poc_pgsubscriber_1 psql -U postgres -d pg_logical_replication_results -c 'SELECT COUNT(*) FROM hashes;'
 count
-------
  2000
(1 row)
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
