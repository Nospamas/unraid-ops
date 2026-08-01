# 16 — Build the Caddy image and stand the proxy up

Type: task
Status: open
Blocked by: 07, 11, 14, 15

## Question

The execution half of [04](04-reverse-proxy-and-domain.md). Everything is
decided; this makes it real.

Do:

- **Write the Dockerfile** — multi-stage, `caddy:*-builder` running `xcaddy
  build --with github.com/lucaslorentz/caddy-docker-proxy/v2 --with
  github.com/caddy-dns/cloudflare`, then copy the binary onto a stock `caddy`
  base. Its location in the repo is [07](07-repo-layout-and-conventions.md)'s
  call.
- **Declare a Komodo `Build`** in ResourceSync TOML pointing at it, and build it
  on the box. Periphery ships buildx, per the 02 asset.
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
- **Prove it end to end on one service.** Pick a harmless one and label it, then
  confirm `https://<it>.rbrb.in` resolves and serves a valid certificate from the
  LAN.

Blocked by [07](07-repo-layout-and-conventions.md) for where the files live,
[11](11-stand-up-komodo.md) because Komodo must exist to build or deploy
anything, [14](14-cloudflare-zone-and-token.md) for the zone and token, and
[15](15-move-unraid-gui-ports.md) for the ports.

**Not blocked on [08](08-deploy-homepage.md), and does not block it.** 08 proves
the reconcile loop and can be reached by `IP:port`; this ticket proves the
proxy. Whichever lands second gets to put homepage on a hostname.

Resolved when a labelled service answers on `https://<name>.rbrb.in` with a
valid wildcard certificate, and the whole thing — Dockerfile, Build TOML, stack,
labels — reproduces from the repo.
