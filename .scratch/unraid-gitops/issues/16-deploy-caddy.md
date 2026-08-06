---
id: "16"
title: Stand the Caddy proxy up
type: task
status: closed
description: >
  `https://home.rbrb.in` serves a trusted `*.rbrb.in` wildcard, staging first
  and issued on the first attempt. Three quiet failures found: Tailscale's
  masquerade makes 05's guard 403 the tailnet behind published ports, so Caddy
  is host-networked; a single-file bind goes ESTALE on the next git pull; and
  a Procedure cannot update itself. Spawned 29.
touches: [stacks/caddy/]
---

# 16 — Stand the Caddy proxy up

Resolved: 2026-08-03
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
- **Delete `/boot/config/ident.cfg.bak-15`** once Caddy is up.
  [15](15-move-unraid-gui-ports.md) left it deliberately: this ticket is the
  window where someone might want the GUI back on 80 in a hurry.

Blocked by [07](07-repo-layout-and-conventions.md) for where the files live,
[11](11-stand-up-komodo.md) because Komodo must exist to build or deploy
anything, [14](14-cloudflare-zone-and-token.md) for the zone and token, and
[15](15-move-unraid-gui-ports.md) for the ports — **15 is closed**, so this is
takeable. It verified that a container binds `0.0.0.0:80` and `:443` on this
box, so the bind is not a risk this ticket carries. The GUI now answers on
`8008`, which is also the port to reconnect on if Caddy has to be torn down.

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
- ~~Caddy joins the `shared` network like everything else~~ — **overturned by
  this ticket**: Caddy is `network_mode: host` and joins nothing, for the
  source-IP reason in the resolution. It still is **not** a deploy-order
  dependency, and it still reaches every Service by its `shared` address.

~~Also do here: **write `scripts/check-exposure.sh`**~~ — **already done by
[13](13-local-tooling.md)**, which wrote it and wired it into `just lint` (the
runner is `just`, not go-task). Nothing to write; just make sure the Caddy stack
passes it.

## Resolution (2026-08-03)

**`https://home.rbrb.in` serves homepage on a trusted `*.rbrb.in` wildcard, and
the whole thing reproduces from the repo.** Let's Encrypt staging first, as
instructed; it issued on the first attempt, which retired 14's token as proven.
The GUI never left 8008 and `ident.cfg.bak-15` is deleted.

Three findings, none of which any earlier ticket had checked. All three were
things that fail *quietly*.

### Caddy is `network_mode: host`, and that is not a preference

05 told this ticket to verify source-IP preservation rather than assume it. It
does not survive. Behind published ports a tailnet client reached Caddy as
`172.20.0.1`, and the guard 403'd **the path the box is actually reached by**:

```
-A POSTROUTING -j ts-postrouting
-A ts-postrouting -m mark --mark 0x40000/0xff0000 -j MASQUERADE
```

Tailscale masquerades any packet it routes onward, and docker's DNAT into a
container counts as onward. So `100.64.0.0/10` could never have matched — not a
misconfiguration, a structural one.

05 feared this would **fail open**; it failed *closed*, so nothing was ever
exposed. But the tempting repair — adding `172.16.0.0/12` to the guard — is the
fiction 05 warned about, because it would admit anything arriving through docker
NAT, including a future published path. Host networking removes docker NAT from
the path instead, and `CADDY_INGRESS_NETWORKS=shared` is what keeps `{{upstreams}}`
resolving once Caddy joins no network. **05's convention is unblocked and its
snippet is unchanged.**

Verified in both directions rather than assumed: tailnet client and a
`192.168.1.x` source get 200; `127.0.0.1` and a container on `shared` get 403.
A genuinely off-box LAN client is the one case left — see the hand-off.

### Bind the directory, never the file

The second deploy **took Caddy down**, and git reported success:

```
Failed to read Caddyfile ... open /etc/caddy/Caddyfile: stale file handle
[ERROR] Removing invalid block: File to import not found: internal
```

A git pull replaces a file rather than writing it in place, and the run
directory is on shfs, so a single-file bind goes ESTALE the first time the file
changes. Losing the base Caddyfile loses the `(internal)` snippet, and
caddy-docker-proxy then **discards every generated block that imports it** — so
Caddy served nothing rather than serving it unguarded. `stacks/caddy/conf/Caddyfile`
now, bound as a directory. Homepage's `./config` never hit this, which is why it
went unnoticed until a second Stack had a config file.

### A Procedure cannot update itself

Editing `komodo/procedures.toml` to add `caddy` failed the whole reconcile.
Komodo refuses to update a resource while it is busy, and `reconcile` **is** the
Procedure running the sync that would update it — ten retries, then
`procedure sync loop exited after max iterations` with the real reason
discarded by Komodo's own error path.

`RunSync` was always idempotent; the constraint is *who* runs it. `just
reconcile` now runs the sync bare first, then the Procedure, whose own sync
stage finds no changes — still one recipe. **The cron only runs the Procedure**,
so a `procedures.toml` edit that lands without `just reconcile` fails every 15
minutes, silently, until someone runs it. That is the sharpest argument yet for
the map's monitoring fog.

`scripts/komodo.sh` also now prints nested failures instead of an update id.

### Smaller rulings

- **Caddy is not built**, per 12: `ghcr.io/serfriz/caddy-cloudflare-dockerproxy`
  is confirmed to be exactly 04's planned xcaddy build, `version@digest`.
- **The `*.rbrb.in` block is load-bearing.** Caddy ≥2.10 prefers a managed
  wildcard over per-subdomain certificates *only if the config names one*; with
  just `home.rbrb.in` in play it would quietly have taken out a certificate per
  hostname. It doubles as the catch-all, so an unclaimed name gets a 404.
- **No `email` in the Caddyfile** — it would be either the human's address in a
  public repo or a parse error whenever `secrets.env` is absent. The cost is
  that Let's Encrypt cannot send expiry warnings, which belongs to the
  monitoring fog rather than here.
- **Homepage lost its `3000:3000`**, the port 08 marked temporary until Caddy,
  and `HOMEPAGE_ALLOWED_HOSTS` collapses to `home.rbrb.in`. The label is now the
  whole access story.
- **The docker socket stayed a direct `:ro` bind**, as this ticket specified,
  rather than going through `dockerproxy` — which denies `EVENTS` and `NETWORKS`
  by default, so it would need widening to serve caddy-docker-proxy at all.
  Worth revisiting only if something else needs the socket.
- **`webmail.rbrb.in` is still reserved** (14) and is unaffected: it is a real
  proxied record, so it never falls through the wildcard to Caddy.
