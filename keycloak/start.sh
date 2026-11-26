#!/usr/bin/env bash
# Keycloak's start wrapper (E03 spec B-5, B-6; plan issue OUT-151). Keycloak has no option that
# reads a password from a file, so this copies the mounted secret files into a config file on a
# tmpfs, readable by Keycloak's user only, and starts kc.sh with it. The passwords are never in the
# container's environment or command, so neither `docker inspect` nor /proc/<pid>/environ shows
# them, and no child process inherits them (M0013). Passwords are alphanumeric (B-2), so no quoting.
set -euo pipefail
umask 077
conf=/run/keycloak/keycloak.conf
{
  printf 'db-password=%s\n' "$(< /run/secrets/keycloak-db)"
  printf 'bootstrap-admin-password=%s\n' "$(< /run/secrets/keycloak-admin)"
} > "$conf"
# --import-realm skips a realm that already exists, so a second scripts/up changes nothing (A-1).
exec /opt/keycloak/bin/kc.sh --config-file="$conf" start --import-realm
