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

## Current Issue

As soon as `pglogical` is integrated (as part of applying `init.sql` to both Postgres instances), the instances **can’t** communicate with each other:

```bash
pgsubscriber_1  | 2021-03-17 07:58:44.040 GMT [78] ERROR:  could not connect to the postgresql server: could not connect to server: Connection refused
pgsubscriber_1  | 		Is the server running on host "pgsubscriber" (172.19.0.3) and accepting
pgsubscriber_1  | 		TCP/IP connections on port 5432?
pgsubscriber_1  |
pgsubscriber_1  | 2021-03-17 07:58:44.040 GMT [78] DETAIL:  dsn was:  host=pgsubscriber port=5432 dbname=pg_logical_replication_results user=replicate password=qwertz
pgsubscriber_1  | 2021-03-17 07:58:44.040 GMT [78] STATEMENT:  SELECT pglogical.create_subscription(
pgsubscriber_1  | 	  subscription_name := 'subscription',
pgsubscriber_1  | 	  replication_sets := array['hashes'],
pgsubscriber_1  | 	  provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=replicate password=qwertz'
pgsubscriber_1  | 	);
pgsubscriber_1  | psql:/docker-entrypoint-initdb.d/init.sql:29: ERROR:  could not connect to the postgresql server: could not connect to server: Connection refused
pgsubscriber_1  | 	Is the server running on host "pgsubscriber" (172.19.0.3) and accepting
pgsubscriber_1  | 	TCP/IP connections on port 5432?
pgsubscriber_1  |
pgsubscriber_1  | DETAIL:  dsn was:  host=pgsubscriber port=5432 dbname=pg_logical_replication_results user=replicate password=qwertz
pglogical-poc_pgsubscriber_1 exited with code 3
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
