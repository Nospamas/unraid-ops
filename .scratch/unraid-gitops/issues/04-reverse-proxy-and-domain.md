---
id: "04"
title: Choose the reverse proxy and the domain
type: grilling
status: closed
description: >
  Caddy (`caddy-docker-proxy`) on `rbrb.in`, DNS at Cloudflare, certificates
  by DNS-01 wildcard. Traefik was reopened mid-grill and declined on purpose;
  the custom Caddy build this ticket accepted was later dropped by 12.
touches: [stacks/caddy/]
---

# 04 — Choose the reverse proxy and the domain

Resolved: 2026-08-01

## Question

Services will be reached by hostname, not `IP:port`. Settle:

- **Which proxy** — SWAG, Traefik, Caddy, or nginx-proxy-manager. The deciding
  axis is configuration style: Traefik and Caddy take container labels, which
  fits a git-owned compose file well; SWAG and NPM keep their own config, which
  is more state living outside the repo.
- **Which domain**, and who hosts its DNS. This site shares nothing with
  home-ops, so `xgy.im` is not available — this is a fresh name.
- **Certificates** — DNS-01 against the domain's provider, or HTTP-01. DNS-01 is
  the only option if nothing is exposed to the internet.
- **Internal vs external hostnames** — whether a service resolves to the same
  name inside and outside the house, or split-horizon DNS is in play.

The answer names the proxy, the domain, the DNS provider and the cert method.

## Resolution

**Caddy** (`caddy-docker-proxy`) on **`rbrb.in`**, DNS on **Cloudflare**,
certificates by **DNS-01 wildcard**.

### The proxy: Caddy, label-driven

`lucaslorentz/caddy-docker-proxy` — routing declared as labels on each service's
compose file, so a service's route lives in the same git-owned file as the
service itself. Nothing bind-mounted, no proxy config outside the repo.

Traefik was the runner-up and was reopened mid-grilling once the human stated a
preference for stock images — stock `traefik:v3` does Cloudflare DNS-01 natively
with no build at all, which is the single strongest argument against the choice
made here. It was put explicitly and declined: **Caddy stays**, and the build
step is accepted as its price. Do not re-litigate this.

SWAG and nginx-proxy-manager were rejected on the same axis as each other —
their config is state living outside git (files in appdata, an internal SQLite
DB), which fights the destination.

### The image: built, not pulled

Stock `caddy-docker-proxy` has no `caddy-dns/cloudflare` module, and DNS-01
needs it. The human's standing preference is **stock external images where
possible, building only in the absence of a decent external utility** — so the
alternatives were tested first and both fail:

- **acme.sh / lego sidecar** (the "cert-manager shape", raised by the human).
  Rejected on two verified facts: Caddy does **not** watch cert files on disk
  ([caddy#6933](https://github.com/caddyserver/caddy/issues/6933) is an open
  feature request), so renewal needs an explicit `caddy reload --force`; and
  acme.sh's docker deploy hook — the thing that would trigger it — has an
  [open bug in daemon mode](https://github.com/acmesh-official/acme.sh/issues/2785),
  the only mode usable for unattended renewal. A silently failed reload means
  serving an expired cert.
- **Third-party prebuilt images** — rejected as hobbyist images sitting in front
  of every service on the box.

So: a short multi-stage Dockerfile in this repo, `xcaddy`-building
`caddy-docker-proxy` + `caddy-dns/cloudflare`, built **on the box** by a Komodo
[**Build** resource](https://komo.do/docs/build) — a first-class Komodo resource
type declarable in ResourceSync TOML alongside the Stacks, so the image stays as
git-owned as everything else. Unlike the custom-Periphery idea that
[03](03-secrets-handling.md) killed, there is **no chicken-and-egg**: Caddy is
not the thing that runs deploys. The 02 asset already confirmed Periphery ships
buildx.

### The domain: `rbrb.in`

Registered at **Gandi**; **nameservers delegated to Cloudflare**, matching the
human's other domains. No registrar transfer is needed and none is planned —
DNS-01 requires Cloudflare to be *authoritative for the zone*, not to be the
registrar. (Cloudflare Registrar's support for `.in` was not confirmed and is
now moot.)

### Certificates: DNS-01 wildcard

One `*.rbrb.in` wildcard from Let's Encrypt, solved against the Cloudflare API.
Nothing has to be reachable from the internet, so it works today and keeps
working whatever [05](05-remote-access.md) picks; adding a service needs no new
issuance. HTTP-01 was rejected because it would have pre-committed 05 to
forwarded ports before that ticket was grilled, and cannot issue wildcards.

This adds a **sixth live secret** to the set [03](03-secrets-handling.md)
settled at five: a Cloudflare **scoped DNS-edit API token**, zone-limited to
`rbrb.in`, carried in the SOPS `secrets.env` for the Caddy stack.

### Hostnames: one namespace, LAN-pointed, split-horizon deferred

`<service>.rbrb.in` means the same thing everywhere — a single wildcard record
in Cloudflare DNS, flat (no `.tower.` tier).

The human's ruling: **most if not all services are internally available only for
now**; single public records pointing at local IPs; split-horizon is worth
building on the basis of *in future* but is not being built now. So:

- `*.rbrb.in` → **A `192.168.1.195`**, and it **must be DNS-only (grey cloud)** —
  Cloudflare will not proxy a private address.
- **Consequence for [05](05-remote-access.md):** a wildcard pointing at the LAN
  IP breaks the tailnet path the human uses today (`tower` = `100.126.56.26`).
  Reaching services over tailscale then needs `tower` to advertise the LAN
  subnet as a subnet router, or a split-horizon answer. 05 owns that choice.
- **Auth is not decided here.** The map's Secret severity note expected 04 or 05
  to settle what sits in front of calibre's login. 04 does not: with everything
  LAN-only, nothing is on the internet yet. It falls wholly to **05**, and only
  bites when something is actually published.

### What this drags into other tickets

- **[07](07-repo-layout-and-conventions.md)** — the layout must carry a shared
  external `proxy` docker network that every fronted service joins, docker
  socket access for `caddy-docker-proxy`, and a home for the Dockerfile plus its
  Komodo `Build` TOML.
- **[12](12-image-update-strategy.md)** — one image is now *built*, not pulled;
  Renovate must track a base image tag **and** a Go module, not a tag alone.
- **New ticket [14](14-cloudflare-zone-and-token.md)** — create the zone,
  delegate the nameservers, mint the scoped token, add the wildcard record.
- **New ticket [15](15-move-unraid-gui-ports.md)** — Unraid's own nginx holds
  80/443; the GUI moves to 8008/8443 before Caddy can bind them.
- **New ticket [16](16-deploy-caddy.md)** — build the image and stand Caddy up.
