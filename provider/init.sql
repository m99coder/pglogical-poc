-- create extension
CREATE EXTENSION IF NOT EXISTS pglogical;

-- create node
SELECT pglogical.create_node(
  node_name := 'provider',
  dsn := 'host=0.0.0.0 port=5432 dbname=postgres'
);

-- create replication set
SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);
