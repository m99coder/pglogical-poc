-- drop subscription
SELECT pglogical.drop_subscription(
  subscription_name := 'pglogical_pgbench_history',
  ifexists := true
);

-- drop node
SELECT pglogical.drop_node(
  node_name := 'subscriber',
  ifexists := true
);
