#!/usr/bin/env bash
# Kafka's start script, in place of the image's command (design checkpoint §4.10 "Kafka"
# steps 1 to 4; spec D-1). It reads the SCRAM and JAAS passwords from /run/secrets at run
# time, so they never appear in the container's command or environment, or in
# `docker inspect` (M0013).
set -euo pipefail
umask 077
src=/opt/setpiece
conf=/tmp/kafka
data=/var/lib/kafka/data
mkdir -p "$conf"

secret() { cat "/run/secrets/$1"; }
admin=$(secret kafka-admin)
# Passwords are alphanumeric (secrets-init), so they are safe in a sed replacement.
sed "s|@ADMIN_PASSWORD@|$admin|" "$src/server.properties.tmpl" > "$conf/server.properties"
sed "s|@ADMIN_PASSWORD@|$admin|" "$src/admin.properties.tmpl" > "$conf/admin.properties"

# The cluster id is made once and kept on the data volume, so a restart never reformats.
[ -s "$data/cluster.id" ] || /opt/kafka/bin/kafka-storage.sh random-uuid > "$data/cluster.id"
/opt/kafka/bin/kafka-storage.sh format --ignore-formatted -t "$(cat "$data/cluster.id")" \
  -c "$conf/server.properties" \
  --add-scram "SCRAM-SHA-512=[name=admin,password=$admin]" \
  --add-scram "SCRAM-SHA-512=[name=connect,password=$(secret kafka-connect)]" \
  --add-scram "SCRAM-SHA-512=[name=connect-producer,password=$(secret kafka-connect-producer)]"

# --ignore-formatted skips --add-scram on a formatted volume, so a new ./secrets would leave the
# old admin credential in place and the health check failing with no reason given. Keep a hash
# of the admin password on the volume and stop with the fix if it no longer matches. kafka-init
# re-sets connect and connect-producer from their files on every run.
hash=$(printf '%s:%s' "$(cat "$data/cluster.id")" "$admin" | sha256sum | cut -d' ' -f1)
if [ ! -e "$data/admin.sha256" ]; then
  printf '%s' "$hash" > "$data/admin.sha256"
elif [ "$(cat "$data/admin.sha256")" != "$hash" ]; then
  echo "kafka/start.sh: secrets/kafka-admin changed since this volume was formatted." >&2
  echo "kafka/start.sh: restore the old file, or remove the volume (docker compose down -v)." >&2
  exit 1
fi

exec /opt/kafka/bin/kafka-server-start.sh "$conf/server.properties"
