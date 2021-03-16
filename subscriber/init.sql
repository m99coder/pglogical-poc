-- create extension
CREATE EXTENSION IF NOT EXISTS pglogical;

-- create node
SELECT pglogical.create_node(
  node_name := 'subscriber',
  dsn := 'host=0.0.0.0 port=5433 dbname=postgres'
);

-- create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'subscription',
  provider_dsn := 'host=0.0.0.0 port=5432 dbname=postgres'
);
