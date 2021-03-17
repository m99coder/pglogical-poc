-- create database
CREATE DATABASE pg_logical_replication_results;
\c pg_logical_replication_results;

-- create table
CREATE TABLE posts (entry_id INT, user_id INT, PRIMARY KEY(entry_id));

-- create extension
CREATE EXTENSION pglogical;
