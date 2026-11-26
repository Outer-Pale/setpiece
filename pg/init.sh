#!/bin/sh
# pg-init's entrypoint. libpq ignores a password file that others can read, and secret files are
# 0444 (§4.12b), so the superuser's password goes into a 0600 copy on the container's tmpfs.
# It is never in the environment or the command (M0013, spec B-6).
set -eu
umask 077
pass=/tmp/pgpass
printf 'postgres:5432:*:postgres:%s\n' "$(cat /run/secrets/postgres-superuser)" > "$pass"
PGPASSFILE=$pass exec psql -X -q -h postgres -U postgres -d postgres -f /pg/init.base.sql
