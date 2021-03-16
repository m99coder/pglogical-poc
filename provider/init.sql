-- dummy data
CREATE TABLE sensor_log (
  id           SERIAL PRIMARY KEY NOT NULL,
  location     VARCHAR NOT NULL,
  reading      BIGINT NOT NULL,
  reading_date TIMESTAMP NOT NULL
);

INSERT INTO sensor_log (location, reading, reading_date)
SELECT s.id % 1000, s.id % 100,
       CURRENT_DATE - (s.id || 's')::INTERVAL
  FROM generate_series(1, 1000000) s(id);

-- create extension
CREATE EXTENSION pglogical;

-- create node
SELECT pglogical.create_node(
  node_name := 'provider',
  dsn := 'host=host.docker.internal port=5432 dbname=postgres'
);

-- create replication set
-- SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);
SELECT pglogical.create_replication_set(
  set_name := 'logging',
  replicate_insert := TRUE,
  replicate_update := FALSE,
  replicate_delete := FALSE,
  replicate_truncate := FALSE
);
SELECT pglogical.replication_set_add_table(
  set_name := 'logging',
  relation := 'sensor_log',
  synchronize_data := TRUE
);
