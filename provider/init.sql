-- create database
CREATE DATABASE pg_logical_replication;
\c pg_logical_replication;

-- create table
CREATE TABLE hashes (id SERIAL, value CHAR(33), PRIMARY KEY(value));

-- create data
INSERT INTO hashes (SELECT generate_series(1, 1000), md5(random()::TEXT));

-- create role and grant rights
CREATE ROLE replicate WITH LOGIN PASSWORD 'qwertz' REPLICATION;
GRANT SELECT ON hashes TO replicate;

-- -- create publication
-- CREATE PUBLICATION pub_hashes FOR TABLE hashes;

-- create extension
CREATE EXTENSION pglogical;

-- grant privileges
GRANT USAGE ON SCHEMA pglogical TO replicate;

-- create node
SELECT pglogical.create_node(
  node_name := 'provider',
  dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=replicate password=qwertz'
);

-- create replication set and add table
SELECT pglogical.create_replication_set(
  set_name := 'hashes',
  replicate_insert := TRUE,
  replicate_update := FALSE,
  replicate_delete := FALSE,
  replicate_truncate := FALSE
);
SELECT pglogical.replication_set_add_table(
  set_name := 'hashes',
  relation := 'hashes',
  synchronize_data := TRUE
);
