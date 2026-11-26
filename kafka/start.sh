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

exec /opt/kafka/bin/kafka-server-start.sh "$conf/server.properties"
