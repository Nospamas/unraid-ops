---
id: "05"
title: Decide the remote access approach
type: grilling
status: closed
description: >
  Split-horizon, built now: CoreDNS bound to the tailnet IP, with Tailscale
  Split DNS pointing `rbrb.in` at it. Nothing is published, and everything is
  built default-deny to LAN + tailnet as if it will be. The claim that no LAN-
  side change was needed was false — corrected by 32.
touches: [stacks/caddy/conf/Caddyfile, stacks/coredns/]
---

# 05 — Decide the remote access approach

Resolved: 2026-08-01

## Question

How do you reach the stack from outside the house?

**[04](04-reverse-proxy-and-domain.md) has resolved and narrowed this
considerably.** The human ruled that **most if not all services are internally
available only for now**, and that hostnames use single public records pointing
at local IPs — `*.rbrb.in` → A `192.168.1.195`, grey cloud. Split-horizon is
worth building on *in future* but is explicitly not being built now.

So the original framing is too broad. What actually remains:

- **The tailnet path is now broken, and that is the sharp question.** The human
  reaches the box today over tailscale (`tower` = `100.126.56.26`), but the
  wildcard points at the LAN address, which does not route over the tailnet.
  Either `tower` **advertises `192.168.1.0/24` as a subnet router**, or a
  split-horizon answer arrives earlier than planned, or the wildcard points at
  the tailscale IP instead and non-tailnet LAN devices lose access. Pick one.
- **Whether anything at all is published beyond the tailnet**, now that the
  default is LAN-only. Cloudflare tunnel and forwarded ports are still the two
  candidates if the answer is yes, but neither is needed if it is no.
- **Authentication — this ticket now owns it outright.** The map's Secret
  severity note expected 04 or 05 to settle what sits in front of calibre's
  login. 04 declined it, correctly: with everything LAN-only, nothing is on the
  internet and there is nothing to defend yet. The moment anything is published,
  the question is live here — and calibre's GUI password and qbittorrent's WebUI
  are the two surfaces that matter.

Cert issuance is **not** a constraint on any of this: 04 chose DNS-01, so
certificates never require inbound reachability.

## Resolution

**Split-horizon after all, built now** — CoreDNS serving the tailnet view only.
**Nothing is published**, but everything is designed as though it will be:
services are **default-deny beyond LAN + tailnet**, and publishing is an explicit
per-service opt-in.

### Split-horizon is asymmetric, and much cheaper than 04 assumed

04 deferred split-horizon as "a resolver, which is a service the map has not
scoped". That over-priced it. Cloudflare's public `*.rbrb.in` → `192.168.1.195`
**already is the LAN view**, served for free by the record 04 chose. Only the
*tailnet* half needs overriding. So this costs **one resolver container serving
one domain**, not a DNS overhaul — and no router or DHCP change whatsoever.

> **Corrected by [32](32-lan-resolver.md).** The last clause was false and
> untested. The public record is the LAN view only for a device that can *hear*
> it, and rb's router at `192.168.1.254` strips every answer in
> `192.168.0.0/16` — so no device using it resolved any `rbrb.in` name for the
> life of this map. Every verification came from the tailnet, which routes
> around that router. It did take a DHCP change: the router now hands out
> `1.1.1.1, 8.8.8.8`. The rest of this section stands — the tailnet half is
> still the only one CoreDNS serves.

The subnet-router option was put and **declined**. It would have kept a single
answer everywhere, but it depends on the remote network not also being
`192.168.1.0/24` — an extremely common home and hotel range — and a shadowed
route fails silently. Pointing the wildcard at `100.126.56.26` instead was also
declined: it breaks every household device not on the tailnet.

| Client | Resolves via | Gets | Reaches Caddy at |
|---|---|---|---|
| LAN device | public Cloudflare | `192.168.1.195` | LAN address |
| Tailnet device (anywhere) | Tailscale Split DNS → CoreDNS | `100.126.56.26` | box's tailnet address |
| Tailnet device *on* the LAN | Split DNS → CoreDNS | `100.126.56.26` | tailscale direct-connects over LAN — no penalty |
| Tailnet device with tailscale off | public Cloudflare | `192.168.1.195` | works on LAN, fails away — correct |

**No subnet router is needed.** Tailnet clients hit Caddy on the box's own
tailnet IP; nothing has to route into `192.168.1.0/24`.

### The resolver: CoreDNS, bound to the tailscale IP only

`coredns/coredns` — official CNCF image, config is a single git-owned Corefile,
**zero runtime state**. Chosen on 04's axis: config in git, not state in appdata.

- **AdGuard Home and Technitium were rejected** on exactly the ground 04 rejected
  SWAG and nginx-proxy-manager — UI-driven appliances whose config is a state DB
  outside the repo.
- **dnsmasq** has the simplest config of all (`address=/rbrb.in/100.126.56.26`,
  one line) but ships **no official image**. It lost on packaging, not merit;
  building one for a one-line config is not worth it.
- **blocky** was the close runner-up — fully git-owned YAML, wildcard subdomain
  matching for free, and ad-blocking in reserve. Lost to CoreDNS on being a
  single-maintainer project rather than a foundation image.

```
# Corefile
rbrb.in {
    template IN A   { answer "{{ .Name }} 60 IN A 100.126.56.26" }
    template IN AAAA { }        # NODATA, not NXDOMAIN
}
. {
    forward . 1.1.1.1
}
```

**Bind on `100.126.56.26:53` only, not `0.0.0.0:53`.** `tailscaled` on Linux
already binds `100.100.100.100:53` for MagicDNS; a container publishing
`0.0.0.0:53` will fail with `EADDRINUSE`. Binding the box's tailnet address is
both the fix and a bonus — the resolver is never exposed to the LAN at all.

### Tailscale side: MagicDNS is a prerequisite

Tailscale has **no static-record feature**. Split DNS points a domain at a
*nameserver*, and MagicDNS only serves `*.ts.net` — which is why a resolver is
genuinely unavoidable here, not a matter of taste. (`tailscale serve` was the
other escape hatch: it gives `tower.<tailnet>.ts.net` with a Tailscale-issued
cert, but collapses `<service>.rbrb.in` into path-routing on one hostname and
duplicates Caddy. Rejected.)

So: **MagicDNS on**, then Split DNS `rbrb.in` → `100.126.56.26`. Enabling
MagicDNS changes DNS behaviour on `earth` and `uranus` — DNS routes through
`100.100.100.100` and a `ts.net` search domain appears. Benign, but real, and it
is a **console setting, not git state** — the same category as the Cloudflare
zone in [14](14-cloudflare-zone-and-token.md).

### Nothing published — but built as if it will be

No Cloudflare tunnel, no forwarded ports. Tailscale covers remote access, and
that is the only access needed. Two facts made this easy:

- **Plex is separable.** It publishes `32400/tcp` and reaches remote clients
  through `plex.tv` direct-connect or Plex Relay, **entirely bypassing Caddy**.
  Publishing nothing through the proxy does not touch Plex remote access.
- **Forwarded ports would have reopened the DNS decision.** The wildcard would
  have to point at the public IP, LAN access would depend on router hairpin NAT,
  and the LAN view would then need its own resolver after all.

The human's standing instruction: *nothing published yet, but treat it as if we
will in future.*

### Default-deny, explicit publish opt-in

This is the ticket's real output, and it is a **convention**, not a workload.
Every service carries a Caddy guard admitting only `192.168.1.0/24` (LAN) and
`100.64.0.0/10` (tailnet), 403 otherwise:

```
(internal) {
    @external not remote_ip 192.168.1.0/24 100.64.0.0/10
    respond @external 403
}
```

Applied **by default to every service** via a `caddy.import: internal` label.
A service meant to face the internet — the human named a future status page as
the likely first — must **declare it explicitly**, and that declaration stands
out in review. Publishing is never a side effect of adding a service.

Note what this is and is not: it is the **gate**, not the **defence**. It does no
work today, because nothing is published. Its value is that the mechanism exists
*before* it is needed, so the first publish is a one-line, visible, per-service
act rather than an event that quietly exposes everything.

### Authentication: deferred, not settled

The map expected 04 or 05 to settle what sits in front of calibre's login and
qbittorrent's WebUI. **05 does not settle it either** — it removes the deadline.
With nothing published, LAN + tailnet is the trust boundary, unchanged from the
box as found; Caddy makes nothing more reachable than `IP:port` already is.

The question goes back to the map as **fog**, and becomes live the moment either
is true: a service is published through the opt-in above, or the LAN stops being
treated as trusted (guest wifi or IoT sharing the subnet). Recorded so it is
closed rather than quietly dropped.

### What this drags into other tickets

- **[07](07-repo-layout-and-conventions.md)** — the add-a-service convention must
  carry the `internal` guard by default, and the Caddyfile snippet needs a home.
- **[16](16-deploy-caddy.md)** — the guard depends on **source-IP preservation**.
  Docker's iptables DNAT preserves the client IP, but the userland-proxy path
  does not. A guard that sees `172.18.0.1` for everything fails open on nothing
  and closed on everything. Verify, do not assume.
- **New ticket [17](17-deploy-coredns.md)** — deploy CoreDNS.
- **New ticket [18](18-tailnet-split-dns.md)** — MagicDNS + Split DNS in the
  admin console.
- **Container scope grows** — CoreDNS is a new workload, alongside Caddy from 04.
- **No new secrets.** The set stays at the six [04](04-reverse-proxy-and-domain.md)
  left it at.
