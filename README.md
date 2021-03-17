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

Try to add more posts to the provider instance and check if the replication worked.

```bash
docker exec -it pglogical-poc_pgprovider_1 \
  psql -U postgres -d pg_logical_replication \
    -c 'INSERT INTO posts (SELECT generate_series(1001, 2000), FLOOR(random()*50)+1);'
INSERT 0 1000
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
  set_name := 'posts',
  replicate_insert := TRUE,
  replicate_update := FALSE,
  replicate_delete := FALSE,
  replicate_truncate := FALSE
);

-- add table to replication set
SELECT pglogical.replication_set_add_table(
  set_name := 'posts',
  relation := 'posts',
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
  replication_sets := array['posts'],
  provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);

-- show subscription status
SELECT * FROM pglogical.show_subscription_status(
  subscription_name := 'subscription'
);

-- show subscription table
SELECT * FROM pglogical.show_subscription_table(
  subscription_name := 'subscription',
  relation := 'posts'
);

-- show `pglogical` relations
\dt pglogical.

-- describe `pglogical.local_sync_status`
\d+ pglogical.local_sync_status

-- show local sync status
SELECT sync_status
  FROM pglogical.local_sync_status
  WHERE sync_nspname = 'public' AND sync_relname = 'posts';
```

The sync states are defined [here](https://github.com/2ndQuadrant/pglogical/blob/REL2_x_STABLE/pglogical_sync.h#L43-L51) and mean the following:

- `\0`: `SYNC_STATUS_NONE` (No sync)
- `i`: `SYNC_STATUS_INIT` (Ask for sync)
- `s`: `SYNC_STATUS_STRUCTURE` (Sync structure)
- `d`: `SYNC_STATUS_DATA` (Sync data)
- `c`: `SYNC_STATUS_CONSTAINTS` (Sync constraints)
- `w`: `SYNC_STATUS_SYNCWAIT` (Table sync is waiting to get OK from main thread)
- `u`: `SYNC_STATUS_CATCHUP` (Catching up)
- `y`: `SYNC_STATUS_SYNCDONE` (Sync finished at lsn)
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

_Column descriptions_

- `slot_name`: A unique, cluster-wide identifier for the replication slot
- `plugin`: The base name of the shared object containing the output plugin this logical slot is using, or null for physical slots.
- `slot_type`: The slot type - `physical` or `logical`
- `datoid`: The OID of the database this slot is associated with, or null. Only logical slots have an associated database.
- `database`: The name of the database this slot is associated with, or null. Only logical slots have an associated database.
- `temporary`: True if this is a temporary replication slot. Temporary slots are not saved to disk and are automatically dropped on error or when the session has finished.
- `active`: True if this slot is currently actively being used
- `active_pid`: The process ID of the session using this slot if the slot is currently actively being used. `NULL` if inactive.
- `xmin`: The oldest transaction that this slot needs the database to retain. `VACUUM` cannot remove tuples deleted by any later transaction.
- `catalog_xmin`: The oldest transaction affecting the system catalogs that this slot needs the database to retain. `VACUUM` cannot remove catalog tuples deleted by any later transaction.
- `restart_lsn`: The address (`LSN`) of oldest WAL which still might be required by the consumer of this slot and thus won’t be automatically removed during checkpoints. `NULL` if the `LSN` of this slot has never been reserved.
- `confirmed_flush_lsn`: The address (`LSN`) up to which the logical slot’s consumer has confirmed receiving data. Data older than this is not available anymore. `NULL` for physical slots.

The `pg_lsn` data type can be used to store LSN (Log Sequence Number) data which is a pointer to a location in the WAL. This type is a representation of `XLogRecPtr` and an internal system type of PostgreSQL.

Internally, an LSN is a 64-bit integer, representing a byte position in the write-ahead log stream. It is printed as two hexadecimal numbers of up to 8 digits each, separated by a slash; for example, `16/B374D848`. The `pg_lsn` type supports the standard comparison operators, like `=` and `>`. Two LSNs can be subtracted using the `-` operator; the result is the number of bytes separating those write-ahead log locations.

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
pid              | 103
usesysid         | 10
usename          | postgres
application_name | subscription
client_addr      | 192.168.96.3
client_hostname  |
client_port      | 55122
backend_start    | 2021-03-17 14:20:21.858559+00
backend_xmin     |
state            | streaming
sent_lsn         | 0/1826A68
write_lsn        | 0/1826A68
flush_lsn        | 0/1826A68
replay_lsn       | 0/1826A68
write_lag        |
flush_lag        |
replay_lag       |
sync_priority    | 0
sync_state       | async

pg_logical_replication=# exit
```

_Column descriptions_

- `pid`: Process ID of a WAL sender process
- `usesysid`: OID of the user logged into this WAL sender process
- `usename`: Name of the user logged into this WAL sender process
- `application_name`: Name of the application that is connected to this WAL sender
- `client_addr`: IP address of the client connected to this WAL sender. If this field is `NULL`, it indicates that the client is connected via a Unix socket on the server machine.
- `client_hostname`: Host name of the connected client, as reported by a reverse DNS lookup of `client_addr`. This field will only be non-null for IP connections, and only when `log_hostname` is enabled.
- `client_port`: TCP port number that the client is using for communication with this WAL sender, or `-1` if a Unix socket is used
- `backend_start`: Time when this process was started, i.e., when the client connected to this WAL sender
- `backend_xmin`: This standby’s `xmin` horizon reported by `hot_standby_feedback`.
- `state`: Current WAL sender state. Possible values are:
  - `startup`: This WAL sender is starting up
  - `catchup`: This WAL sender’s connected standby is catching up with the primary
  - `streaming`: This WAL sender is streaming changes after its connected standby server has caught up with the primary
  - `backup`: This WAL sender is sending a backup
  - `stopping`: This WAL sender is stopping
- `sent_lsn`: Last write-ahead log location sent on this connection
- `write_lsn`: Last write-ahead log location written to disk by this standby server
- `flush_lsn`: Last write-ahead log location flushed to disk by this standby server
- `replay_lsn`: Last write-ahead log location replayed into the database on this standby server
- `write_lag`: Time elapsed between flushing recent WAL locally and receiving notification that this standby server has written it (but not yet flushed it or applied it). This can be used to gauge the delay that `synchronous_commit` level `remote_write` incurred while committing if this server was configured as a synchronous standby.
- `flush_lag`: Time elapsed between flushing recent WAL locally and receiving notification that this standby server has written and flushed it (but not yet applied it). This can be used to gauge the delay that `synchronous_commit` level on incurred while committing if this server was configured as a synchronous standby.
- `replay_lag`: Time elapsed between flushing recent WAL locally and receiving notification that this standby server has written, flushed and applied it. This can be used to gauge the delay that `synchronous_commit` level `remote_apply` incurred while committing if this server was configured as a synchronous standby.
- `sync_priority`: Priority of this standby server for being chosen as the synchronous standby in a priority-based synchronous replication. This has no effect in a quorum-based synchronous replication.
- `sync_state`: Synchronous state of this standby server. Possible values are:
  - `async`: This standby server is asynchronous
  - `potential`: This standby server is now asynchronous, but can potentially become synchronous if one of current synchronous ones fails.
  - `sync`: This standby server is synchronous
  - `quorum`: This standby server is considered as a candidate for quorum standbys

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
sync_relname   | posts
sync_status    | r
sync_statuslsn | 0/1822C70
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
