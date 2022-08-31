BEGIN;
INSERT INTO posts SELECT MAX(id) + 1, FLOOR(random() * 50) + 1 FROM posts;
END;
