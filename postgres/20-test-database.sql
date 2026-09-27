-- Separate login cannot connect to siga; Flyway test migrations run only in this database.
\set ON_ERROR_STOP on
\getenv test_password SIGA_TEST_PASSWORD
SELECT format('CREATE ROLE siga_iam_test LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'test_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'siga_iam_test')
\gexec
SELECT 'CREATE DATABASE siga_identity_local_test OWNER siga_iam_test'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'siga_identity_local_test')
\gexec
REVOKE CONNECT ON DATABASE siga_identity_local_test FROM PUBLIC;
