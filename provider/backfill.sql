-- backfill column
UPDATE comments
  SET approved_by = 'me'
  WHERE approved_by = 'me';
