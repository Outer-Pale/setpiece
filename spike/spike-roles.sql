-- The K-3 test database and its two roles (E03 spec §2a; design checkpoint §4.3).
-- Run as the superuser by spike-init on every K-3 run, so every statement is safe to repeat.
\set ON_ERROR_STOP on
\set owner_pw `cat /run/secrets/spike_owner`
\set cdc_pw `cat /run/secrets/spike_cdc`

select format('create role %I login', r) from unnest(array['spike_owner', 'spike_cdc']) r
  where not exists (select 1 from pg_roles where rolname = r) \gexec
alter role spike_owner password :'owner_pw';
-- The CDC role reads the publication over a logical replication connection (§4.3).
alter role spike_cdc password :'cdc_pw' replication;

select 'create database spike owner spike_owner'
  where not exists (select 1 from pg_database where datname = 'spike') \gexec
revoke all on database spike from public;
grant connect on database spike to spike_cdc;
