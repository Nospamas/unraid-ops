# 22 — Migrate calibre

Type: task
Status: open
Assignee: Nospamas

## Question

Adopt calibre into git. Already **99:100**
([01](01-inventory-running-containers.md)), so
[20](20-chown-to-99-100.md) does not gate it, but it is not uniform with
[21](21-migrate-arr-stacks.md) in three ways — though it **is** uniform in the
one 21 got wrong: calibre is unraid's, not Portainer's, so there is no compose
project to adopt. Run `just adopt calibre --apply` before the first deploy, and
add it to the deploy pattern only once it is free.

- **It carries a secret** — the GUI password — so it is the second Stack with a
  `secrets.sops.env`. Follow [08](08-deploy-homepage.md)'s correction: the
  decrypted `secrets.env` reaches the container through compose's `env_file`
  with `required: false`, not `additional_env_files`.
- **Three host ports**: 8080 (desktop GUI over guacamole), 8081 (content
  server), 8181. Decide which of these Caddy will front later, and whether all
  three still need publishing.
- **The `${MEDIA}/books` → `/config/Calibre Library` bind**, space and all
  ([docs/conventions.md](../../../docs/conventions.md)).

The map's *Secret severity* note rules the calibre password low-value and
**closed** — do not reopen it. The live carve-out is auth in front of its login,
and that is fog until something is published.
