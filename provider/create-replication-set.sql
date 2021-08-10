-- create replication set
SELECT pglogical.create_replication_set(
  set_name := 'pgbench',
  replicate_insert := true,
  replicate_update := false,
  replicate_delete := false,
  replicate_truncate := false
);

-- add tables to replication set
SELECT pglogical.replication_set_add_table(
  set_name := 'pgbench',
  relation := 'pgbench_history',
  row_filter := 'tid = 1'
);
