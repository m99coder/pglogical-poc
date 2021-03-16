# pglogical-poc

> PostgreSQL 11.5 with pglogical 2.2.2

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

# stop containers
docker-compose down
```

## Resources

- [docker-pglogical](https://github.com/reediculous456/docker-pglogical/blob/master/Dockerfile)
- [Demystifying pglogical](http://thedumbtechguy.blogspot.com/2017/04/demystifying-pglogical-tutorial.html)
- [Short tutorial to setup replication using pglogical](https://gist.github.com/ratnakri/c22a7389d9fab788d7b8b12e2a6c337a)
- [How to configure pglogical](https://www.tutorialdba.com/2018/01/how-to-configure-pglogical-streaming.html)
- [PostgreSQL – logical replication with pglogical](https://blog.dbi-services.com/postgresql-logical-replication-with-pglogical/)
