# 16 — Stand the Caddy proxy up

Type: task
Status: open
Blocked by: 07, 11, 14, 15

## Question

The execution half of [04](04-reverse-proxy-and-domain.md). Everything is
decided; this makes it real.

Do:

- ~~**Write the Dockerfile**~~ and ~~**declare a Komodo `Build`**~~ —
  **both dropped by [12](12-image-update-strategy.md).** Caddy is no longer
  built. Pull `ghcr.io/serfriz/caddy-cloudflare-dockerproxy`, pinned
  `version@digest` like every other image; it is exactly this build, maintained
  upstream. There is no Dockerfile, no `[[build]]`, and no build stage in the
  reconcile Procedure. 12 records the four-line Dockerfile as an escape hatch if
  serfriz goes stale — and if it is ever needed, the build happens in **GitHub
  Actions**, not on the box.
- **Create the shared external `proxy` network** and deploy the Caddy stack on
  it, binding host **80 and 443** (free only after
  [15](15-move-unraid-gui-ports.md)) and mounting the docker socket **read-only**
  — `caddy-docker-proxy` reads labels from it and never needs to write.
- **Wire DNS-01**: the Cloudflare token from
  [14](14-cloudflare-zone-and-token.md), decrypted into `secrets.env` by the
  stack's `pre_deploy` hook per [03](03-secrets-handling.md), and a global
  Caddyfile snippet setting the `acme_dns cloudflare` module.
- **Issue and verify the `*.rbrb.in` wildcard.** Use Let's Encrypt **staging**
  first — DNS-01 failures are easy to hit and the production rate limits are
  unforgiving.
- **Add the `(internal)` snippet from [05](05-remote-access.md)** to the global
  Caddyfile config, and apply `caddy.import: internal` to the proof service
  below.
- **Verify source-IP preservation — do not assume it.** The `internal` guard is
  `remote_ip 192.168.1.0/24 100.64.0.0/10`, which is worthless if Caddy sees a
  docker bridge address instead of the client. Docker's iptables DNAT preserves
  the source IP; the userland-proxy path does not. Log or echo the observed
  `remote_ip` for a request from a LAN client and confirm it is a `192.168.1.x`.
  If it is `172.x`, the guard silently admits everything and the whole default-
  deny posture is fiction — that is a finding, and it blocks 05's convention
  until solved.
- **Prove it end to end on one service.** Pick a harmless one and label it, then
  confirm `https://<it>.rbrb.in` resolves and serves a valid certificate from the
  LAN — and that a request from outside both CIDRs gets a 403.

Blocked by [07](07-repo-layout-and-conventions.md) for where the files live,
[11](11-stand-up-komodo.md) because Komodo must exist to build or deploy
anything, [14](14-cloudflare-zone-and-token.md) for the zone and token, and
[15](15-move-unraid-gui-ports.md) for the ports.

**Not blocked on [08](08-deploy-homepage.md), and does not block it.** 08 proves
the reconcile loop and can be reached by `IP:port`; this ticket proves the
proxy. Whichever lands second gets to put homepage on a hostname.

Resolved when a labelled service answers on `https://<name>.rbrb.in` with a
valid wildcard certificate, and the whole thing — stack, Caddyfile, labels —
reproduces from the repo.

## Settled by [07](07-repo-layout-and-conventions.md)

The file locations this ticket deferred are now fixed — nothing left to decide,
only to do:

- ~~`stacks/caddy/Dockerfile`~~ and ~~the `[[build]]`~~ — void, per
  [12](12-image-update-strategy.md). `stacks/caddy/komodo.toml` holds a
  `[[stack]]` only.
- `stacks/caddy/Caddyfile` is a **real bind-mounted file**, not labels on the
  Caddy container, and it holds the global options plus the `(internal)` snippet
  that every service's `caddy.import: internal` resolves to.
- The Cloudflare token is `stacks/caddy/secrets.sops.env`, decrypted by the
  Stack's `pre_deploy`.
- ~~The built image is the **only** bare tag in the repo~~ — **overturned by
  [12](12-image-update-strategy.md).** There are no bare tags anywhere; Caddy is
  `version@digest` like everything else, and is **human-merged**, never
  automerged, because it fronts every hostname.
- Caddy joins the `shared` network like everything else; it does not own or
  create it. Every Stack's `pre_deploy` creates it idempotently, so Caddy is
  **not** a deploy-order dependency for the rest of the box.

~~Also do here: **write `scripts/check-exposure.sh`**~~ — **already done by
[13](13-local-tooling.md)**, which wrote it and wired it into `just lint` (the
runner is `just`, not go-task). Nothing to write; just make sure the Caddy stack
passes it.
