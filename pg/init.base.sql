-- The base databases and roles: Keycloak, OpenFGA and monitor (design checkpoint §4.3).
-- Run by pg-init on every scripts/up, so every statement is safe to repeat.
-- `create role` and `create database` use \gexec, because `create database` can't run in a DO
-- block and psql variables aren't substituted inside dollar quotes (§4.3).
\set ON_ERROR_STOP on

\set keycloak_pw `cat /run/secrets/keycloak-db`
\set openfga_pw `cat /run/secrets/openfga-db`
\set monitor_pw `cat /run/secrets/monitor-db`

select format('create role %I login', r) from unnest(array['keycloak', 'openfga', 'monitor']) r
  where not exists (select 1 from pg_roles where rolname = r) \gexec

-- Passwords are set on every run, so a rotated secret file takes effect.
alter role keycloak password :'keycloak_pw';
alter role openfga  password :'openfga_pw';
alter role monitor  password :'monitor_pw';

-- monitor runs the Collector's slot query (§4.3).
grant pg_monitor to monitor;

select format('create database %I owner %I', d, d) from unnest(array['keycloak', 'openfga', 'monitor']) d
  where not exists (select 1 from pg_database where datname = d) \gexec

-- Only the owner (and the superuser) may connect to each base database (§4.3).
revoke connect on database postgres from public;
revoke all on database keycloak from public;
revoke all on database openfga from public;
revoke all on database monitor from public;
