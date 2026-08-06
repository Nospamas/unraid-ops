---
id: "37"
title: Point the bare domain at homepage
type: task
status: open
description: >
  `rbrb.in` 308s to `home.rbrb.in`, so there is one canonical hostname. The
  apex needs its own site block and its own cert — the wildcard covers neither
  — plus a new Cloudflare A record, and a ruling on whether the redirect
  imports the guard.
touches: [stacks/caddy/conf/Caddyfile]
---

# 37 — Point the bare domain at homepage

Blocked by: —

## Question

`rbrb.in` in a browser bar should reach homepage. Today it reaches nothing.

**Decided while charting: the apex 308s to `home.rbrb.in`**, rather than serving
homepage directly. One canonical hostname, so nothing can work on one name and
break on the other, and `home.rbrb.in` stays the name every existing reference
already uses.

### Four facts this ticket turns on

1. **`*.rbrb.in` does not match `rbrb.in`.** A wildcard covers one label, not the
   apex. The [Caddyfile](../../../stacks/caddy/conf/Caddyfile)'s wildcard block
   therefore never sees the bare domain, and the wildcard **certificate** does
   not cover it either — the apex needs its own site block and its own cert.
   ACME over the existing `acme_dns cloudflare` handles the issuance.
2. **Cloudflare needs a new A record for the apex.** The wildcard DNS record does
   not cover it any more than the cert does. Human action, at Cloudflare.
3. **CoreDNS already answers the apex.** The
   [Corefile](../../../stacks/coredns/conf/Corefile)'s `rbrb.in` block templates
   every name in the zone including the zone itself, so the tailnet half is free
   and needs no edit.
4. **`HOMEPAGE_ALLOWED_HOSTS` is `home.rbrb.in`** in
   [stacks/homepage/compose.yaml](../../../stacks/homepage/compose.yaml), and
   homepage rejects any Host header not on that list. A redirect sidesteps this
   entirely — the browser arrives bearing `home.rbrb.in` — which is one of the
   reasons the redirect won. **Serving the apex directly would have needed this
   edit, and the failure would have looked like a Caddy bug.**

### Already true, do not build

**HTTP→HTTPS redirects work.** Caddy auto-redirects for every site it holds a
cert for, and [16](16-deploy-caddy.md) put Caddy on 80 and 443 host-networked.
Verified while charting, not assumed. Nothing to do.

### The guard

Decide whether the apex block imports `internal`. It is a redirect, not a
service, so a 308 leaks only the existence of the name — but every other block in
that file imports the guard, and departing from that silently is how a default
erodes. Recommend importing it and saying why on the record either way.

### Rollback

Required by [CLAUDE.md](../../../CLAUDE.md), since this edits Caddy's config and
Caddy holds 80 and 443:

**`git revert` the commit, then `just redeploy caddy`.** Komodo stays reachable
at `:9120` and the Unraid GUI at `:8008` throughout — both keep their host ports
precisely so the tooling that repairs Caddy does not sit behind Caddy
([26](26-host-state-scope.md)). Deploy and confirm `home.rbrb.in` still answers
**before** confirming the apex does.

## Hand-offs

- **Create an A record for `rbrb.in` → `192.168.1.195`** at Cloudflare, DNS-only
  (not proxied), matching the existing wildcard. The apex resolves nowhere on
  rb's LAN until this exists.
