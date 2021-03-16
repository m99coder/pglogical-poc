-- create database
CREATE DATABASE pg_logical_replication_results;
\c pg_logical_replication_results;

-- create table
CREATE TABLE hashes (id SERIAL, value CHAR(33), PRIMARY KEY(value));

-- create role and grant rights
CREATE ROLE replicate WITH LOGIN PASSWORD 'qwertz' REPLICATION;
GRANT SELECT ON hashes TO replicate;

-- -- create subscription
-- CREATE SUBSCRIPTION sub_hashes CONNECTION 'host=pgprovider dbname=pg_logical_replication user=replicate password=qwertz' PUBLICATION pub_hashes;

-- create extension
CREATE EXTENSION pglogical;

-- create node
SELECT pglogical.create_node(
  node_name := 'subscriber',
  dsn := 'host=pgsubscriber port=5433 dbname=pg_logical_replication_results user=replicate password=qwertz'
);

-- create subscription
SELECT pglogical.create_subscription(
  subscription_name := 'subscription',
  replication_sets := array['hashes'],
  provider_dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=replicate password=qwertz'
);
