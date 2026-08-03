# 22 — Migrate calibre

Type: task
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03

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

## Resolution (2026-08-03)

**Calibre is a Stack, on `shared`, reachable only at `https://calibre.rbrb.in`,
with its library intact** — `metadata.db` and the author directories mount
exactly as before through the `${MEDIA}/books` → `/config/Calibre Library` bind.
Adoption was [21](21-migrate-arr-stacks.md)'s procedure unchanged: `just adopt
calibre --apply`, then one Stack added to the deploy pattern, then reconcile.
Pinned to `v8.15.0-ls371`, the digest already running.

### All three host ports are gone, and that is the ticket's real answer

The question was which of 8080, 8081 and 8181 Caddy would front. The answer is
**one, and the other two were never load-bearing**:

- **8081, the content server, has nothing listening behind it.** `ss -ltn`
  inside the running container showed 8080, 8181 and an internal 8082 — no
  8081 at all. The port had been published for years onto nothing.
- **8181 is the same GUI over a self-signed cert.** `CUSTOM_PORT=8080` and
  `CUSTOM_HTTPS_PORT=8181` are two doors into one application, and Caddy
  terminating a real wildcard makes the self-signed one strictly worse.
- **8080 needs no publishing either.** Unlike the *arr in
  [30](30-arr-urls-on-shared.md), nothing addresses calibre but a browser —
  lazylibrarian's `universal-calibre` mod runs `calibredb` against the shared
  `/books` mount, not over HTTP. So there is no in-app URL to strand, and
  `caddy.import: internal` is the entire access story.

Verified both ways: 401 from the tailnet (the GUI demanding its login, so the
secret arrived), 403 from a container on `shared`.

### The env was mostly cargo

The running container carried 25 variables. Diffing them against the image's own
`Config.Env` showed the unraid template had set only **PUID, PGID, UMASK, TZ,
CUSTOM_USER, PASSWORD**, an empty `CLI_ARGS`, and unraid's own `HOST_*`.
`START_DOCKER`, `CUSTOM_PORT`, `DISPLAY`, `TITLE`, `QTWEBENGINE_DISABLE_SANDBOX`
and the rest are image defaults. **Diff against the image before copying an env
block forward** — it is the difference between adopting a service and adopting
someone's screenshot of it.

### The secret

Second Stack with one, written with `just secret calibre` and reaching the
container through compose's `env_file`. Landed `0600` on the box, so
[19](19-secret-hygiene-on-the-box.md)'s `umask 077` subshell holds. Credentials
carried over **unchanged** — 19 ruled them low-value and closed, and changing
them here would have been a second change in an adoption window.

### What is left in unraid's Docker tab

**`PortainerCE`, and nothing else.** Every workload the box runs is now
compose's, which makes `just adopt` finished work rather than a standing tool —
[25](25-retire-portainer.md) destroys Portainer, it does not adopt it.
