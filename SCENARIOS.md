# Scenarios

## Column with default value

We run a migration that adds a column with a default value. When we try to replicate the respective table an error occurs.

```bash
# start containers
docker-compose up -d

# run migrations
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /migration.sql

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -f /migration.sql

# check schema
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication \
    -c '\d+ comments'
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication \
    -c 'SELECT * FROM comments LIMIT 1;'

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -c '\d+ comments'

# configure and start replication
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /replication.sql

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -f /replication.sql

# check logs
docker logs pglogical-poc-pgsubscriber-1
```

```text
2022-07-11 09:52:31.084 GMT [124] ERROR:  null value in column "approved_by" violates not-null constraint
2022-07-11 09:52:31.084 GMT [124] DETAIL:  Failing row contains (51, 976, 1, t, null).
2022-07-11 09:52:31.084 GMT [124] CONTEXT:  COPY comments, line 1: "51  976     1       t       \N"
2022-07-11 09:52:31.084 GMT [124] STATEMENT:  COPY "public"."comments" ("id","post_id","user_id","deleted","approved_by") FROM stdin
```

Solution: We backfill the default value to materialize it before replicating it.

```bash
# stop containers and clean up
docker-compose down --rmi all

# start containers with rebuilding images
docker-compose up -d --build

# run migrations
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /migration.sql

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -f /migration.sql

# run backfill
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /backfill.sql

# configure and start replication
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /replication.sql

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -f /replication.sql

# check logs
docker logs pglogical-poc-pgsubscriber-1

# check entries
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication \
    -c 'SELECT * FROM comments WHERE user_id = 1;'

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results \
    -c 'SELECT * FROM comments;'
```

Solution: We use a volatile function to provide the default value.

```bash
# stop containers and clean up
docker-compose down --rmi all

# start containers with rebuilding images
docker-compose up -d --build

# run migrations
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /migration-2.sql

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -f /migration-2.sql

# configure and start replication
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication -f /replication.sql

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results -f /replication.sql

# check logs
docker logs pglogical-poc-pgsubscriber-1

# check entries
docker exec -it pglogical-poc-pgprovider-1 \
  psql -U postgres -d pg_logical_replication \
    -c 'SELECT * FROM comments WHERE user_id = 1;'

docker exec -it pglogical-poc-pgsubscriber-1 \
  psql -U postgres -d pg_logical_replication_results \
    -c 'SELECT * FROM comments;'
```
