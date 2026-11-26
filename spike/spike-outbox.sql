-- The §4.2 outbox, heartbeat, publication and grants, run as spike_owner (E03 spec K-3).
-- This is the chassis migration's SQL, copied from design checkpoint §4.2, made repeatable.
\set ON_ERROR_STOP on

create table if not exists chassis_outbox (
  seq            bigint generated always as identity primary key,
  id             uuid   not null unique,
  kind           text   not null check (kind in ('event','command','audit')),
  topic          text   not null,
  aggregatetype  text,
  aggregateid    text   not null,
  type           text   not null,
  payload        jsonb  not null,
  ce_subject     text   not null,
  ce_time        timestamptz not null default now(),
  ce_dataschema  text   not null,
  ce_tenantid    text   not null,
  ce_aggregateversion bigint,
  ce_correlationid text,
  ce_causationid text,
  ce_traceparent text,
  ce_authtype    text   not null,
  ce_authid      text   not null,
  ce_authclaims  text
);
create unique index if not exists chassis_outbox_version on chassis_outbox
  (ce_tenantid, aggregatetype, aggregateid, ce_aggregateversion) where kind = 'event';
-- D-014 option (a), not yet in §4.2: InsertHeader cannot stamp the string 1.0, so the constant
-- rides as a column placed as a header. `add column if not exists` keeps reruns repeatable.
alter table chassis_outbox add column if not exists ce_specversion text not null default '1.0';
create table if not exists chassis_heartbeat (id int primary key, at timestamptz not null);

select 'create publication chassis_outbox_pub for table chassis_outbox, chassis_heartbeat with (publish = ''insert, update'')'
  where not exists (select 1 from pg_publication where pubname = 'chassis_outbox_pub') \gexec
do $$ begin
  execute format('grant select on chassis_outbox, chassis_heartbeat to %I', current_database() || '_cdc');
  execute format('grant insert, update on chassis_heartbeat to %I', current_database() || '_cdc');
end $$;
