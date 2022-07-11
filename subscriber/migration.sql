-- add column
ALTER TABLE comments
  ADD COLUMN approved_by TEXT DEFAULT 'me' NOT NULL;
