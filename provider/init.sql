-- create database
CREATE DATABASE pg_logical_replication;
\c pg_logical_replication;

-- create table
CREATE TABLE hashes (id SERIAL, value CHAR(33), PRIMARY KEY(value));

-- create data
INSERT INTO hashes (SELECT generate_series(1, 1000), md5(random()::TEXT));

-- create role
CREATE ROLE replicate WITH LOGIN PASSWORD 'qwertz' REPLICATION;

-- create publication
CREATE PUBLICATION pub_hashes FOR TABLE hashes;

-- grant rights
GRANT SELECT ON hashes TO replicate;

-- -- create replicator user
-- CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'my_replicator_password';

-- -- dummy data
-- CREATE TABLE sensor_log (
--   id           SERIAL PRIMARY KEY NOT NULL,
--   location     VARCHAR NOT NULL,
--   reading      BIGINT NOT NULL,
--   reading_date TIMESTAMP NOT NULL
-- );

-- INSERT INTO sensor_log (location, reading, reading_date)
-- SELECT s.id % 1000, s.id % 100, CURRENT_DATE - (s.id || 's')::INTERVAL
--   FROM generate_series(1, 1000000) s(id);

-- -- create extension
-- CREATE EXTENSION pglogical;

-- -- create node
-- SELECT pglogical.create_node(
--   node_name := 'provider',
--   dsn := 'host=127.0.0.1 port=5432 dbname=logging user=replicator password=my_replicator_password'
-- );

-- -- create replication set
-- SELECT pglogical.create_replication_set(
--   set_name := 'logging',
--   replicate_insert := TRUE,
--   replicate_update := FALSE,
--   replicate_delete := FALSE,
--   replicate_truncate := FALSE
-- );
-- SELECT pglogical.replication_set_add_table(
--   set_name := 'logging',
--   relation := 'sensor_log',
--   synchronize_data := TRUE
-- );
