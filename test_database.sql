-- PostgreSQL fallback dump
SET session_replication_role = 'replica';

DROP TABLE IF EXISTS "users" CASCADE;
CREATE TABLE "users" (
"id" integer NOT NULL DEFAULT nextval('users_id_seq'),
"name" text NULL
);

INSERT INTO "users" ("id", "name") VALUES (1, 'Alice');
INSERT INTO "users" ("id", "name") VALUES (2, 'Bob's Team');
