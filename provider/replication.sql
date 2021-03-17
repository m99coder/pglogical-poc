-- create node
SELECT pglogical.create_node(
  node_name := 'provider',
  dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);

-- create replication set
SELECT pglogical.create_replication_set(
  set_name := 'posts',
  replicate_insert := TRUE,
  replicate_update := FALSE,
  replicate_delete := FALSE,
  replicate_truncate := FALSE
);

-- add table to replication set
SELECT pglogical.replication_set_add_table(
  set_name := 'posts',
  relation := 'posts',
  row_filter := 'user_id = 1',
  synchronize_data := TRUE
);
