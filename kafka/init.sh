#!/usr/bin/env bash
# kafka-init: signs in as admin and creates the base users, topics and ACLs (design
# checkpoint §4.10 "kafka-init signs in as admin and creates three things"; spec D-2).
# Every step is safe to repeat: users other than admin are set from their secret files on
# every run, topics use --if-not-exists, and adding an ACL that exists changes nothing.
set -euo pipefail
umask 077
bin=/opt/kafka/bin
cfg=/tmp/admin.properties
sed "s|@ADMIN_PASSWORD@|$(cat /run/secrets/kafka-admin)|" /opt/setpiece/admin.properties.tmpl > "$cfg"
k=(--bootstrap-server kafka:9092 --command-config "$cfg")

# Users: svc-* (§4.10), and connect and connect-producer again, whose first credentials come
# from start.sh's format, which a formatted volume skips. The password is on kafka-configs' command line inside this container only, as
# kafka-storage's --add-scram is in start.sh; it is never in `docker inspect` (M0013).
user() {
  "$bin/kafka-configs.sh" "${k[@]}" --alter --entity-type users --entity-name "$1" \
    --add-config "SCRAM-SHA-512=[password=$(cat "/run/secrets/kafka-$1")]" > /dev/null
}
user connect
user connect-producer
user svc-collector
user svc-spike

# Topics. ev.spike.example is step 1's test topic (§6 step 1). Retention (R-10) is step 7's.
"$bin/kafka-topics.sh" "${k[@]}" --create --if-not-exists --topic ev.spike.example \
  --partitions 3 --replication-factor 1

# ACLs. acl <principal> <kafka-acls.sh arguments>
acl() { "$bin/kafka-acls.sh" "${k[@]}" --add --allow-principal "User:$1" "${@:2}" > /dev/null; }

# connect: its internal topics, which it creates itself (auto-create is off), and its group.
for t in connect-configs connect-offsets connect-status; do
  acl connect --topic "$t" --operation Create --operation Describe --operation DescribeConfigs \
    --operation Read --operation Write
done
acl connect --group connect-cluster --operation Read

# connect-producer: the only principal that writes events (§4.2, "two layers").
for p in ev. audit. cmd.; do
  acl connect-producer --topic "$p" --resource-pattern-type prefixed --operation Write --operation Describe
done

# svc-collector: reads consumer group offsets for the lag metric (§4.10 Logs; M0018).
acl svc-collector --group '*' --operation Describe
acl svc-collector --topic '*' --operation Describe

# svc-spike: the read-only test principal (§6 step 1), its topic and its own group prefix.
acl svc-spike --topic ev.spike.example --operation Read --operation Describe
acl svc-spike --group svc-spike --resource-pattern-type prefixed --operation Read

echo "kafka-init: users, topics and ACLs in place"
