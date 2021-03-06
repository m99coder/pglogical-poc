-- create node
SELECT pglogical.create_node(
  node_name := 'subscriber',
  dsn := 'host=pgsubscriber port=5432 dbname=pg_logical_replication_results user=postgres password=s3cr3t'
);

-- create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'pglogical_subscription',
  replication_sets := array['example'],
  provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);

-- wait for sync complete
SELECT pglogical.wait_for_subscription_sync_complete('pglogical_subscription');
