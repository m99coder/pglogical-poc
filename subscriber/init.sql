-- create database
CREATE DATABASE pg_logical_replication_results;
\c pg_logical_replication_results;

-- create tables
CREATE TABLE users (id INT, PRIMARY KEY(id));
CREATE TABLE posts (id INT, user_id INT, PRIMARY KEY(id));
CREATE TABLE comments (
  id INT,
  post_id INT,
  user_id INT,
  deleted BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY(id)
);

-- create extension
CREATE EXTENSION pglogical;
