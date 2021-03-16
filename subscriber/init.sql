-- dummy data
CREATE TABLE sensor_log (
  id           INT PRIMARY KEY NOT NULL,
  location     VARCHAR NOT NULL,
  reading      BIGINT NOT NULL,
  reading_date TIMESTAMP NOT NULL
);

-- create extension
CREATE EXTENSION pglogical;

-- create node
SELECT pglogical.create_node(
  node_name := 'subscriber',
  dsn := 'host=127.0.0.1 port=5999 dbname=logging user=replicator password=my_replicator_password'
);

-- create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'subscription',
  replication_sets := array['logging'],
  provider_dsn := 'host=127.0.0.1 port=5432 dbname=logging user=replicator password=my_replicator_password'
);

-- test replication
SELECT pg_sleep(5);
SELECT COUNT(*) FROM sensor_log;
