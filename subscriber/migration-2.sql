-- add volatile function
CREATE OR REPLACE FUNCTION get_default() RETURNS TEXT AS $$
  SELECT TEXT 'me' AS result;
$$ LANGUAGE SQL;

-- add column
ALTER TABLE comments
  ADD COLUMN approved_by TEXT DEFAULT get_default() NOT NULL;
