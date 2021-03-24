-- create node
SELECT pglogical.create_node(
  node_name := 'provider',
  dsn := 'host=pgprovider port=5432 dbname=pg_logical_replication user=postgres password=s3cr3t'
);

-- create replication set
SELECT pglogical.create_replication_set(
  set_name := 'example'
);

-- add tables to replication set
SELECT pglogical.replication_set_add_table(
  set_name := 'example',
  relation := 'users',
  row_filter := 'id = 1'
);

SELECT pglogical.replication_set_add_table(
  set_name := 'example',
  relation := 'posts',
  row_filter := 'user_id = 1'
);

SELECT pglogical.replication_set_add_table(
  set_name := 'example',
  relation := 'comments',
  row_filter := 'user_id = 1'
);
