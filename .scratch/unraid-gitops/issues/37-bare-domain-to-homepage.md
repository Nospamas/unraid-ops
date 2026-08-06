---
id: "37"
title: Point the bare domain at homepage
type: task
status: closed
description: >
  `rbrb.in` 308s to `home.rbrb.in` from its own block and its own cert. The
  guard is imported inside a `route`, which is load-bearing: Caddy sorts
  `redir` ahead of `respond`, so the obvious spelling would have 308'd the
  whole internet while reading as guarded.
touches: [stacks/caddy/conf/Caddyfile, stacks/gatus/conf/config.yaml, docs/conventions.md]
---

# 37 — Point the bare domain at homepage

Resolved: 2026-08-06
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

## Answer

`rbrb.in` 308s to `https://home.rbrb.in{uri}`, from its own site block and its
own cert. Four of the five facts above held exactly as charted; the fifth is
below.

### The guard is imported, and `route` is what makes that true

Recommended and taken: the apex imports `internal` like every other block. A 308
leaks only the name's existence, but a redirect that stays reachable when the
thing it points at is not is a door left ajar for no gain, and departing
silently from the file's one default is how a default erodes.

**But the obvious spelling does not work.** Caddy's directive order puts `redir`
*ahead* of `respond`, so this:

```
rbrb.in {
	import internal
	redir https://home.rbrb.in{uri} 308
}
```

adapts to the 308 handler first and the guard's 403 second — unreachable. The
block would have read as guarded in review, passed the lint, and 308'd every
client on the internet. `route` restores the written order:

```
rbrb.in {
	route {
		import internal
		redir https://home.rbrb.in{uri} 308
	}
}
```

Both spellings were run through `caddy adapt` in the running container and the
JSON compared, rather than trusting the docs' order table. The Caddyfile's
existing note — "`respond` sorts before `reverse_proxy`, so this ends the chain
first" — is true and does not generalise: it holds for every other block in the
file precisely because they all end in `reverse_proxy`.

The rule is in [conventions.md](../../../docs/conventions.md), *Routing*.

### Verified, not assumed

From a tailnet client, and from the box for the guard:

| check | result |
|---|---|
| `home.rbrb.in` still answers, checked **before** the apex | 200 |
| `https://rbrb.in/` | 308 → `https://home.rbrb.in/` |
| `https://rbrb.in/foo?bar=1` | 308 → `https://home.rbrb.in/foo?bar=1` — `{uri}` carries path and query |
| apex certificate | issued, `CN=rbrb.in`, verifies |
| `http://rbrb.in/` | 308 → `https://rbrb.in/`, Caddy's own — nothing built [16] |
| the apex from `127.0.0.1` on the box | **403** — the guard runs, which is the `route` fix proved end to end |

### It gets a probe

`bare domain`, in gatus's `infrastructure` group — it is a route, not a service.
It asserts 308 with `ignore-redirect: true`; following the redirect would report
homepage's 200 and the front door could break unseen. It earns its place on a
failure nothing else covers: **the apex is outside the wildcard cert, so its
issuance can fail while every `*.rbrb.in` probe stays green.** Green on the box.

The probe does not wait on the hand-off below: CoreDNS templates the whole zone
including the apex, confirmed by asking it, and gatus is pinned to CoreDNS.

## Hand-offs

None left. The A record `rbrb.in` → `192.168.1.195` **already exists** — rb had
set it before this ticket ran, and 1.1.1.1 and 8.8.8.8 both return it. Grey
cloud, which the answer itself proves: Cloudflare will not proxy a private
address [14]. No AAAA beside it.

The LAN leg is the one link not tested end to end — it is unreachable from the
tailnet, where this session ran. It is the same address and the same Caddy that
already serve every `*.rbrb.in` name on that network.
