#!/usr/bin/env bash
# Keycloak's start wrapper (E03 spec B-5, B-6; plan issue OUT-151). Keycloak has no option that
# reads a password from a file, so this reads the mounted secret files at run time and hands them
# to kc.sh in its own environment. They never appear in the container's configured environment or
# command, so `docker inspect` shows neither (M0013).
set -euo pipefail
KC_DB_PASSWORD=$(< /run/secrets/keycloak-db)
KC_BOOTSTRAP_ADMIN_PASSWORD=$(< /run/secrets/keycloak-admin)
export KC_DB_PASSWORD KC_BOOTSTRAP_ADMIN_PASSWORD
# --import-realm skips a realm that already exists, so a second scripts/up changes nothing (A-1).
exec /opt/keycloak/bin/kc.sh start --import-realm
