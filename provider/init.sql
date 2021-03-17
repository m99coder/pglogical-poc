-- create database
CREATE DATABASE pg_logical_replication;
\c pg_logical_replication;

-- create table
CREATE TABLE posts (entry_id INT, user_id INT, PRIMARY KEY(entry_id));

-- create data
INSERT INTO posts (SELECT generate_series(1, 1000), FLOOR(random()*50)+1);

-- create extension
CREATE EXTENSION pglogical;
