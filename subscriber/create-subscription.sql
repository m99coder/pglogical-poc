-- create node
SELECT pglogical.create_node(
  node_name := 'subscriber',
  dsn := 'host=pgsubscriber port=5432 dbname=pg_logical_replication_results user=postgres password=s3cr3t'
);

-- create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'pglogical_pgbench_history',
  replication_sets := array['pgbench'],
  provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);
