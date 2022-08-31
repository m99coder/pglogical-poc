# pglogical

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

## Requirements

To use pglogical the provider and subscriber must be running PostgreSQL 9.4 or newer. The `pglogical` extension must be installed on both provider and subscriber. You must `CREATE EXTENSION pglogical` on both. Tables on the provider and subscriber must have the same names and be in the same schema. Tables on the provider and subscriber must have the same columns, with the same data types in each column. `CHECK` constraints, `NOT NULL` constraints, etc. must be the same or weaker (more permissive) on the subscriber than the provider. Tables must have the same `PRIMARY KEY`s. It is not recommended to add additional `UNIQUE` constraints other than the `PRIMARY KEY`.

## Usage

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

### SQL Interfaces

```sql
/**
 * Creates a node
 * @param {name} node_name
 *   name of the node, only one node is allowed per database
 * @param {text} dsn
 *   connection string to the node, for nodes that are supposed to be
 *   providers, this should be reachable from outside
 */
pglogical.create_node(node_name name, dsn text)

/**
 * Drops the pglogical node
 * @param {name} node_name
 *   name of an existing node
 * @param {boolean} exists
 *   if true, error is not thrown when subscription does not exist, default is
 *   false
 */
pglogical.drop_node(node_name name, ifexists boolean)

/**
 * Adds additional interface to a node. When node is created, the interface for
 * it is also created with the dsn specified in the create_node and with the
 * same name as the node. This interface allows adding alternative interfaces
 * with different connection strings to an existing node.
 * @param {name} node_name
 *   name of an existing node
 * @param {name} interface_name
 *   name of a new interface to be added
 * @param {text} dsn
 *   connection string to the node used for the new interface
 */
pglogical.alter_node_add_interface(node_name name, interface_name name, dsn text)

/**
 * Remove existing interface from a node.
 * @param {name} node_name
 *   name of an existing node
 * @param {name} interface_name
 *   name of an existing interface
 */
pglogical.alter_node_drop_interface(node_name name, interface_name name)

/**
 * Creates a subscription from current node to the provider node. Command does
 * not block, just initiates the action.
 * @param {name} subscription_name
 *   name of the subscription, must be unique
 * @param {text} provider_dsn
 *   connection string to a provider
 * @param {text[]} replication_sets
 *   array of replication sets to subscribe to, these must already exist,
 *   default is `{default,default_insert_only,ddl_sql}`
 * @param {boolean} synchronize_structure
 *   specifies if to synchronize structure from provider to the subscriber,
 *   default is false
 * @param {boolean} synchronize_data
 *   specifies if to synchronize data from provider to the subscriber, default
 *   is true
 * @param {text[]} forward_origins
 *   array of origin names to forward, currently only supported values are
 *   empty array meaning don’t forward any changes that didn’t originate on
 *   provider node, or `{all}` which means replicate all changes no matter
 *   what is their origin, default is `{all}`
 * @param {integer} apply_delay
 *   how much to delay replication, default is 0 seconds
 */
pglogical.create_subscription(
  subscription_name name,
  provider_dsn text,
  replication_sets text[],
  synchronize_structure boolean,
  synchronize_data boolean,
  forward_origins text[],
  apply_delay integer
)

/**
 * Disconnects the subscription and removes it from the catalog.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {boolean} ifexists
 *   if true, error is not thrown when subscription does not exist, default
 *   is false
 */
pglogical.drop_subscription(subscription_name name, ifexists boolean)

/**
 * Disables a subscription and disconnects it from the provider.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {boolean} immediate
 *  if true, the subscription is stopped immediately, otherwise it will be only
 *  stopped at the end of current transaction, default is false
 */
pglogical.alter_subscription_disable(subscription_name name, immediate boolean)

/**
 * Enables disabled subscription
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {boolean} immediate
 *  if true, the subscription is started immediately, otherwise it will be only
 *  started at the end of current transaction, default is false
 */
pglogical.alter_subscription_enable(subscription_name name, immediate boolean)

/**
 * Switch the subscription to use different interface to connect to provider
 * node.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {name} interface_name
 *   name of an existing interface of the current provider node
 */
pglogical.alter_subscription_interface(subscription_name name, interface_name name)

/**
 * All unsynchronized tables in all sets are synchronized in a single operation.
 * Tables are copied and synchronized one by one. Command does not block, just
 * initiates the action.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {boolean} truncate
 *   if true, tables will be truncated before copy, default false
 */
pglogical.alter_subscription_synchronize(subscription_name name, truncate boolean)

/**
 * Resynchronize one existing table.
 * WARNING: This function will truncate the table first.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {regclass} relation
 *   name of existing table, optionally qualified
 */
pglogical.alter_subscription_resynchronize_table(
  subscription_name name,
  relation regclass
)

/**
 * Shows status and basic information about subscription.
 * @param {name} subscription_name
 *   optional name of the existing subscription, when no name was provided,
 *   the function will show status for all subscriptions on local node
 */
pglogical.show_subscription_status(subscription_name name)

/**
 * Shows synchronization status of a table.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {regclass} relation
 *   name of existing table, optionally qualified
 */
pglogical.show_subscription_table(subscription_name name, relation regclass)

/**
 * Adds one replication set into a subscriber. Does not synchronize, only
 * activates consumption of events.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {name} replication_set
 *   name of replication set to add
 */
pglogical.alter_subscription_add_replication_set(
  subscription_name name,
  replication_set name
)

/**
 * Removes one replication set from a subscriber.
 * @param {name} subscription_name
 *   name of the existing subscription
 * @param {name} replication_set
 *   name of replication set to remove
 */
pglogical.alter_subscription_remove_replication_set(
  subscription_name name,
  replication_set name
)
```

Replication sets provide a mechanism to control which tables in the database will be replicated and which actions on those tables will be replicated.

Each replicated set can specify individually if `INSERT`s, `UPDATE`s, `DELETE`s and `TRUCATE`s on the set are replicated. Every table can be in multiple replication sets and every subscriber can subscribe to multiple replication sets as well. The resulting set of tables and actions replicated is the union of the sets the table is in. The tables are not replicated until they are added into a replication set.

There are three preexisting replication sets named `default`, `default_insert_only` and `ddl_sql`. The `default` replication set is defined to replicate all changes to tables. The `default_insert_only` only replicates `INSERT`s and is meant for tables that don’t have primary key. The `ddl_sql` replication set is defined to replicate schema changes specified by `pglogical.replicate_ddl_command`.

```sql
/**
 * Creates a new replication set.
 * @param {name} set_name
 *   name of the set, must be unique
 * @param {boolean} replicate_insert
 *   specifies if `INSERT` is replicated, default true
 * @param {boolean} replicate_update
 *   specifies if `UPDATE` is replicated, default true
 * @param {boolean} replicate_delete
 *   specifies if `DELETE` is replicated, default true
 * @param {boolean} replicate_truncate
 *   specifies if `TRUNCATE` is replicated, default true
 */
pglogical.create_replication_set(
  set_name name,
  replicate_insert boolean,
  replicate_update boolean,
  replicate_delete boolean,
  replicate_truncate boolean
)

/**
 * changes the parameters of the existing replication set.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {boolean} replicate_insert
 *   specifies if `INSERT` is replicated, default true
 * @param {boolean} replicate_update
 *   specifies if `UPDATE` is replicated, default true
 * @param {boolean} replicate_delete
 *   specifies if `DELETE` is replicated, default true
 * @param {boolean} replicate_truncate
 *   specifies if `TRUNCATE` is replicated, default true
 */
pglogical.alter_replication_set(
  set_name name,
  replicate_inserts boolean,
  replicate_updates boolean,
  replicate_deletes boolean,
  replicate_truncate boolean
)

/**
 * Removes the replication set.
 * @param {name} set_name
 *   name of the existing replication set
 */
pglogical.drop_replication_set(set_name text)

/**
 * Adds a table to replication set.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {regclass} relation
 *   name or OID of the table to be added to the set
 * @param {boolean} synchronize_data
 *   if true, the table data is synchronized on all subscribers which are
 *   subscribed to given replication set, default is false
 * @param {text[]} columns
 *   list of columns to replicate. Normally when all columns should be
 *   replicated, this will be set to `NULL` which is the default
 * @param {text} row_filter
 *   row filtering expression, default `NULL` (no filtering)
 *   WARNING: Use caution when synchronizing data with a valid row filter.
 *   Using `synchronize_data=true` with a valid `row_filter` is like a
 *   one-time operation for a table. Executing it again with modified
 *   `row_filter` won’t synchronize data to subscriber. Subscribers may need
 *   to call `pglogical.alter_subscription_resynchronize_table()` to fix it.
 */
pglogical.replication_set_add_table(
  set_name name,
  relation regclass,
  synchronize_data boolean,
  columns text[],
  row_filter text
)

/**
 * Adds all tables in given schemas. Only existing tables are added, table
 * that will be created in future will not be added automatically.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {text[]} schema_names
 *   array of names of existing schemas from which tables should be added
 * @param {boolean} synchronize_data
 *   if true, the table data is synchronized on all subscribers which are
 *   subscribed to given replication set, default is false
 */
pglogical.replication_set_add_all_tables(
  set_name name,
  schema_names text[],
  synchronize_data boolean
)

/**
 * Remove a table from replication set.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {regclass} relation
 *   name or OID of the table to be removed from the set
 */
pglogical.replication_set_remove_table(set_name name, relation regclass)

/**
 * Adds a sequence to replication set.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {regclass} relation
 *   name or OID of the sequence to be added to the set
 * @param {boolean} synchronize_data
 *   if true, the sequence value will be synchronized immediately, default
 *   is false
 */
pglogical.replication_set_add_sequence(
  set_name name,
  relation regclass,
  synchronize_data boolean
)

/**
 * Adds all sequences in given schemas. Only existing sequences are added, any
 * sequences that will be created in future will not be added automatically.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {text[]} schema_names
 *   array of names of existing schemas from which sequences should be added
 * @param {boolean} synchronize_data
 *   if true, the sequence value will be synchronized immediately, default
 *   is false
 */
pglogical.replication_set_add_all_sequences(
  set_name name,
  schema_names text[],
  synchronize_data boolean
)

/**
 * Remove a sequence from replication set.
 * @param {name} set_name
 *   name of the existing replication set
 * @param {regclass} relation
 *   name or OID of the sequence to be removed from the set
 */
pglogical.replication_set_remove_sequence(set_name name, relation regclass)
```

You can view the information about which table is in which set by querying the `pglogical.tables` view.

### Row Filtering on Provider

On the provider the row filtering can be done by specifying `row_filter` parameter for the `pglogical.replication_set_add_table` function. The `row_filter` is a normal PostgreSQL expression which has the same limitations on what’s allowed as the `CHECK` constraint.

Simple `row_filter` would look something like `row_filter := 'id > 0'` which would ensure that only rows where values of `id` column is bigger than zero will be replicated. It’s allowed to use a volatile function inside `row_filter` but caution must be exercised with regard to writes as any expression which will do writes will throw error and stop replication.

It’s also worth noting that the `row_filter` is running inside the replication session so session specific expressions such as `CURRENT_USER` will have values of the replication session and not the session which did the writes.

### Row Filtering on Subscriber

On the subscriber the row based filtering can be implemented using standard `BEFORE TRIGGER` mechanism. It is required to mark any such triggers as either `ENABLE REPLICA` or `ENABLE ALWAYS` otherwise they will not be executed by the replication process.

## Conflicts

In case the node is subscribed to multiple providers, or when local writes happen on a subscriber, conflicts can arise for the incoming changes. These are automatically detected and can be acted on depending on the configuration.

The configuration of the conflicts resolver is done via the `pglogical.conflict_resolution` setting. The supported values for the `pglogical.conflict_resolution` are:

- `error`: the replication will stop on error if conflict is detected and manual action is needed for resolving
- `apply_remote`: always apply the change that’s conflicting with local data, this is the default
- `keep_local`: keep the local version of the data and ignore the conflicting change that is coming from the remote node
- `last_update_wins`: the version of data with newest commit timestamp will be be kept (this can be either local or remote version)
- `first_update_wins`: the version of the data with oldest timestamp will be kept (this can be either local or remote version)

The `keep_local`, `last_update_wins` and `first_update_wins` settings require `track_commit_timestamp` PostgreSQL setting to be enabled.
