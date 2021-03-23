# pglogical-poc

> Replicate from PostgreSQL 11.5 to 11.10 using pglogical 2.2.2

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

For a more realistic setup there are three tables created: `users`, `posts`, and `comments`, where `comments` has a foreign key for `posts` and `posts` has a foreign key for `users`. The goal of this PoC is to move everything related to a specific user: 1 row from `users`, x rows from `posts`, and y rows from `comments`.

pglogical currently **doesn’t support sub-queries** in the `row_filter`. So we need an alternative approach.

```
invalid row_filter expression "post_id = IN (SELECT id FROM posts WHERE user_id = 1)"
```

For simplicity we choose de-normalizing the foreign key relation from `comments` to `posts` to `users` by adding a `user_id` column to the `comments` table directly, that will be populated with the randomly chosen `user_id` values set in `posts` table.

Now run replication queries:

```bash
# first for the provider:
#   - pglogical.create_node
#   - pglogical.create_replication_set
#   - pglogical.replication_set_add_table
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication -f /replication.sql

# second for the subscriber:
#   - pglogical.create_node
#   - pglogical.create_subscription
docker exec -it pglogical-poc_pgsubscriber_1 \
  psql -U postgres -d pg_logical_replication_results -f /replication.sql
```

And finally, check if the correct number of posts was replicated based on the arbitrary row filter `user_id = 1`:

```bash
# get number of posts having `user_id = 1`
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication \
    -c 'SELECT COUNT(*) FROM posts WHERE user_id = 1;'
 count
-------
    19
(1 row)

# get number of replicated posts
docker exec -it pglogical-poc_pgsubscriber_1 \
  psql -U postgres -d pg_logical_replication_results \
    -c 'SELECT COUNT(*) FROM posts;'
 count
-------
    19
(1 row)
```

_The actual number of posts can differ between runs, as the initial data is generated randomly. The important thing is that the two numbers are indeed equal._

Try to add more posts and comments to the provider instance and check if the replication worked.

```bash
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication \
    -c 'INSERT INTO posts (SELECT generate_series(1001, 2000), FLOOR(random()*50)+1);'
INSERT 0 1000

docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication \
    -c 'INSERT INTO comments (SELECT generate_series(201, 400), FLOOR(random()*1000)+1);'
INSERT 0 200

docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication \
    -c 'UPDATE comments
SET user_id = subquery.user_id
FROM (
  SELECT posts.user_id, comments.id
  FROM posts
  INNER JOIN comments ON posts.id = comments.post_id
) AS subquery
WHERE comments.id = subquery.id;'
UPDATE 400
```

SQL queries as plain text for convenience:

```sql
-- pgprovider
-- create node
SELECT pglogical.create_node(
  node_name := 'provider',
  dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);

-- create replication set
SELECT pglogical.create_replication_set(
  set_name := 'example'
);

-- add tables to replication set
SELECT pglogical.replication_set_add_table(
  set_name := 'example',
  relation := 'users',
  row_filter := 'id = 1',
  synchronize_data := TRUE
);

SELECT pglogical.replication_set_add_table(
  set_name := 'example',
  relation := 'posts',
  row_filter := 'user_id = 1',
  synchronize_data := TRUE
);

SELECT pglogical.replication_set_add_table(
  set_name := 'example',
  relation := 'comments',
  row_filter := 'user_id = 1',
  synchronize_data := TRUE
);

-- pgsubscriber
-- create subscriber node
SELECT pglogical.create_node(
  node_name := 'subscriber',
  dsn := 'host=pgsubscriber port=5432 dbname=pg_logical_replication_results user=postgres password=s3cr3t'
);

-- create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'subscription',
  replication_sets := array['example'],
  provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);

-- show subscription status
SELECT * FROM pglogical.show_subscription_status(
  subscription_name := 'subscription'
);

-- show subscription table
SELECT * FROM pglogical.show_subscription_table(
  subscription_name := 'subscription',
  relation := 'example'
);

-- show `pglogical` relations
\dt pglogical.

-- describe `pglogical.local_sync_status`
\d+ pglogical.local_sync_status

-- show local sync status
SELECT sync_status
  FROM pglogical.local_sync_status
  WHERE sync_nspname = 'public' AND sync_relname = 'example';

-- show replication stats on provider
SELECT
  pg_current_wal_insert_lsn(),
  replay_lsn,
  pg_size_pretty(pg_current_wal_insert_lsn() - replay_lsn::pg_lsn) AS diff
FROM pg_stat_replication;
```

The sync states are defined [here](https://github.com/2ndQuadrant/pglogical/blob/REL2_x_STABLE/pglogical_sync.h#L43-L51) and mean the following:

- `\0`: `SYNC_STATUS_NONE` (No sync)
- `i`: `SYNC_STATUS_INIT` (Ask for sync)
- `s`: `SYNC_STATUS_STRUCTURE` (Sync structure)
- `d`: `SYNC_STATUS_DATA` (Sync data)
- `c`: `SYNC_STATUS_CONSTAINTS` (Sync constraints)
- `w`: `SYNC_STATUS_SYNCWAIT` (Table sync is waiting to get OK from main thread)
- `u`: `SYNC_STATUS_CATCHUP` (Catching up)
- `y`: `SYNC_STATUS_SYNCDONE` (Sync finished at LSN)
- `r`: `SYNC_STATUS_READY` (Sync done)

Determine replication status

```bash
# check replication slots on provider
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication
psql (11.5 (Debian 11.5-3.pgdg90+1))
Type "help" for help.

pg_logical_replication=# \x
Expanded display is on.
pg_logical_replication=# SELECT * FROM pg_replication_slots;
-[ RECORD 1 ]-------+------------------------------------------
slot_name           | pgl_pg_logic194f0de_provider_subscription
plugin              | pglogical_output
slot_type           | logical
datoid              | 16384
database            | pg_logical_replication
temporary           | f
active              | t
active_pid          | 103
xmin                |
catalog_xmin        | 577
restart_lsn         | 0/1826A30
confirmed_flush_lsn | 0/1826A68

pg_logical_replication=# exit
```

Find column descriptions [here](https://www.postgresql.org/docs/11/view-pg-replication-slots.html).

```bash
# check current WAL insert LSN
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication
psql (11.5 (Debian 11.5-3.pgdg90+1))
Type "help" for help.

pg_logical_replication=# \x
Expanded display is on.
pg_logical_replication=# SELECT pg_current_wal_insert_lsn();
-[ RECORD 1 ]-------------+----------
pg_current_wal_insert_lsn | 0/18264A8

pg_logical_replication=# exit
```

```bash
# check replication status on provider
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication
psql (11.5 (Debian 11.5-3.pgdg90+1))
Type "help" for help.

pg_logical_replication=# \x
Expanded display is on.
pg_logical_replication=# SELECT * FROM pg_stat_replication;
-[ RECORD 1 ]----+------------------------------
pid              | 101
usesysid         | 10
usename          | postgres
application_name | subscription
client_addr      | 192.168.128.3
client_hostname  |
client_port      | 58410
backend_start    | 2021-03-17 16:48:24.83939+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/18264A8
write_lsn        | 0/18264A8
flush_lsn        | 0/18264A8
replay_lsn       | 0/18264A8
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async

pg_logical_replication=# SELECT pg_size_pretty(pg_current_wal_insert_lsn() - '0/00000000'::pg_lsn);
-[ RECORD 1 ]--+------
pg_size_pretty | 24 MB

pg_logical_replication=# SELECT
pg_logical_replication-#   pg_current_wal_insert_lsn(),
pg_logical_replication-#   replay_lsn,
pg_logical_replication-#   pg_size_pretty(pg_current_wal_insert_lsn() - replay_lsn::pg_lsn) AS diff
pg_logical_replication-# FROM pg_stat_replication;
-[ RECORD 1 ]-------------+----------
pg_current_wal_insert_lsn | 0/1826588
replay_lsn                | 0/1826588
diff                      | 0 bytes

pg_logical_replication=# exit
```

Find column descriptions [here](https://www.postgresql.org/docs/11/monitoring-stats.html#PG-STAT-REPLICATION-VIEW).

```bash
# check local sync status on subscriber
docker exec -it pglogical-poc_pgsubscriber_1 \
  psql -U postgres -d pg_logical_replication_results
psql (11.10 (Debian 11.10-1.pgdg90+1))
Type "help" for help.

pg_logical_replication_results=# \x
Expanded display is on.
pg_logical_replication_results=# SELECT * FROM pglogical.local_sync_status;
-[ RECORD 1 ]--+-----------
sync_kind      | f
sync_subid     | 2875150205
sync_nspname   | public
sync_relname   | example
sync_status    | r
sync_statuslsn | 0/1822758
-[ RECORD 2 ]--+-----------
sync_kind      | d
sync_subid     | 2875150205
sync_nspname   |
sync_relname   |
sync_status    | r
sync_statuslsn | 0/0

pg_logical_replication_results=# exit
```

## Resources

- [PostgreSQL and the logical replication](https://blog.raveland.org/post/postgresql_lr_en/)
- [PostgreSQL replication with Docker](https://medium.com/swlh/postgresql-replication-with-docker-c6a904becf77)
- [Dockerfile](https://gist.github.com/asaaki/b07dccfd6ff6eed4c7b4ef279ade7b0c)
- [docker-pglogical](https://github.com/reediculous456/docker-pglogical/blob/master/Dockerfile)
- [Upgrading PostgreSQL from 9.4 to 10.3 with pglogical](https://hunleyd.github.io/posts/Upgrading-PostgreSQL-from-9.4-to-10.3-with-pglogical/)
- [Demystifying pglogical](http://thedumbtechguy.blogspot.com/2017/04/demystifying-pglogical-tutorial.html)
- [Short tutorial to setup replication using pglogical](https://gist.github.com/ratnakri/c22a7389d9fab788d7b8b12e2a6c337a)
- [How to configure pglogical](https://www.tutorialdba.com/2018/01/how-to-configure-pglogical-streaming.html)
- [PostgreSQL – logical replication with pglogical](https://blog.dbi-services.com/postgresql-logical-replication-with-pglogical/)
- [PG Phriday: Perfectly Logical](http://bonesmoses.org/2016/10/14/pg-phriday-perfectly-logical/)
