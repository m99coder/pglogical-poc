-- drop replication set
SELECT pglogical.drop_replication_set(
  set_name := 'pgbench'
);
