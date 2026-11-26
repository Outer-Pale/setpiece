# setpiece

The Setpiece platform: its services, their contract packages, and the Compose files and scripts that run them on one host (master ADRs 0002 and 0003). Design and decision records live in `Outer-Pale/set-piece-project`.

Nothing runs yet. Build step 1, the host spike, is in progress: see `epics/E03-prove-the-host/` in `Outer-Pale/set-piece-project`.

## Running it

- `scripts/up` starts the platform. It is the only way to start it, and safe to run again. It needs Docker Compose 5.5.1.
- `scripts/secrets-init` writes any missing secret into `./secrets` (git-ignored), from the list in `platform/secrets.base.yaml`. `scripts/up` runs it first.
- `scripts/spike-check <section>...` runs build step 1's checks. CI runs the sections that need no running stack.
- Kong publishes 443 on every host address. If another process already holds 443 on one address (on `harry-msi-server`, tailscaled on the tailnet address), set `SETPIECE_PUBLISH_ADDRESS=<one host address>` in `.env` (git-ignored).
