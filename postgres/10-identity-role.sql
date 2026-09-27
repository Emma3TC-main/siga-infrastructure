-- Provision only a login; Identity/Flyway creates and owns iam.
-- Existing roles/passwords are never replaced. No consolidated model or seed here.
\set ON_ERROR_STOP on
\getenv iam_password SIGA_IAM_PASSWORD
SELECT format('CREATE ROLE siga_iam LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE PASSWORD %L', :'iam_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'siga_iam')
\gexec
GRANT CONNECT, CREATE ON DATABASE siga TO siga_iam;
