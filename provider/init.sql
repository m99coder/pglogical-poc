-- create database
CREATE DATABASE pg_logical_replication;
\c pg_logical_replication;

-- create tables
CREATE TABLE users (id INT, PRIMARY KEY(id));
CREATE TABLE posts (id INT, user_id INT, PRIMARY KEY(id));
CREATE TABLE comments (id INT, post_id INT, PRIMARY KEY(id));

-- create data
INSERT INTO users (SELECT generate_series(1, 50));
INSERT INTO posts (SELECT generate_series(1, 1000), FLOOR(random()*50)+1);
INSERT INTO comments (SELECT generate_series(1, 200), FLOOR(random()*1000)+1);

-- create extension
CREATE EXTENSION pglogical;
