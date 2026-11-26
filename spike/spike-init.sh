#!/bin/sh
# spike-init's entrypoint (E03 spec §2a, K-3). Passwords go into a 0600 file on the container's
# tmpfs, as pg/init.sh does, never into the environment or the command (M0013).
set -eu
umask 077
pass=/tmp/pgpass
{
  printf 'postgres:5432:*:postgres:%s\n' "$(cat /run/secrets/postgres-superuser)"
  printf 'postgres:5432:spike:spike_owner:%s\n' "$(cat /run/secrets/spike_owner)"
} > "$pass"
export PGPASSFILE=$pass
psql -X -q -v ON_ERROR_STOP=1 -h postgres -U postgres -d postgres -f /spike/spike-roles.sql
psql -X -q -v ON_ERROR_STOP=1 -h postgres -U spike_owner -d spike -f /spike/spike-outbox.sql
