# 21 — Migrate sonarr, radarr, prowlarr and lazylibrarian

Type: task
Status: open

## Question

Adopt the four bridge-networked, 99:100 services into git as four Stacks. They
are the uniform case: [01](01-inventory-running-containers.md) has each running
`lscr.io/linuxserver/<name>:latest` on the default bridge, already at
**99:100**, so [20](20-chown-to-99-100.md) does **not** gate them.

[08](08-deploy-homepage.md) proved the route, and it is now repetition rather
than decisions — follow
[docs/adding-a-service.md](../../../docs/adding-a-service.md), including its
two adopt-only steps: **unraid autostart off before the first deploy**, and
confirm the `/config` bind matches what is on disk.

Per service, the things this ticket must get right:

- Pin `version@digest`; every image on the box is still `latest` and months
  stale ([12](12-image-update-strategy.md)).
- Join `shared`, and keep the host port — nothing fronts these until
  [16](16-deploy-caddy.md).
- `TZ` comes from [common.env](../../../common.env) as `America/Vancouver`;
  these four currently say `America/Los_Angeles`. Same offset, so this is a
  cosmetic convergence, not a behaviour change.
- Add each name to the `BatchDeployStackIfChanged` pattern in
  [komodo/procedures.toml](../../../komodo/procedures.toml). A Stack missing
  from that list is never deployed by the loop.
- **The first Deploy of an adopted Stack is unproven** — Komodo matched the
  containers by project name but records nothing as deployed, so whether compose
  recreates or no-ops is its config-hash call. Harmless here (these four have no
  namespace-sharing sidecar), which is exactly why they should go first: they
  answer that question cheaply, before [24](24-migrate-download-stack.md) has to
  rely on it.

Homepage's widget urls for these services point at `{{HOMEPAGE_VAR_HOST}}`;
each migration can switch one to `http://<name>:<port>`.

The answer records what the first Deploy did — recreate or no-op — and whether
anything in the checklist still needed a decision.
