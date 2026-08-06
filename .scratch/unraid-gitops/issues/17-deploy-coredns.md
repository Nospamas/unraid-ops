---
id: "17"
title: Deploy CoreDNS for the tailnet view
type: task
status: closed
description: >
  CoreDNS is live on `100.126.56.26:53` and every `rbrb.in` name answers
  tower's tailnet address, verified from off both networks. The question was
  reopened before it was built and roaming was ruled in scope, which is the
  whole justification for the Stack. `.` REFUSEs rather than forwarding.
touches: [stacks/coredns/]
---

# 17 — Deploy CoreDNS for the tailnet view

Resolved: 2026-08-03
Blocked by: 07, 11

**Read the map's "Two networks" note first.** `192.168.1.0/24` is rb's network,
where tower is; the human sits on a separate home network whose only path to
tower is tailscale, so the public `192.168.1.195` record resolves for them to an
address they cannot route to. **This ticket is what fixes that**, and it is more
load-bearing than "the tailnet view" makes it sound.

**Why not just put the record in pihole**, now that it is known to be editable?
Because pihole is only the resolver *on the home network*. It cannot answer for
the laptop in a café or the phone on cellular — and the destination says
"reachable from outside the house". CoreDNS earns its place on the roaming case,
not on the house.

## Question

The workload half of [05](05-remote-access.md)'s split-horizon answer. Everything
is decided; this makes it real.

Do:

- **Write the Corefile** — `rbrb.in` answered by the `template` plugin as a
  wildcard `A` to `100.126.56.26`, `AAAA` templated to **NODATA** (an empty
  template block) rather than falling through to NXDOMAIN, and a `.` block
  forwarding everything else upstream. Its location in the repo is
  [07](07-repo-layout-and-conventions.md)'s call. The Corefile is the *entire*
  config — CoreDNS holds no runtime state, so nothing lands in appdata.
- **Deploy the stack** on stock `coredns/coredns`, publishing **`100.126.56.26:53`
  on udp and tcp** — an explicit address, **not** `0.0.0.0:53`.
- **Verify no port collision.** `tailscaled` binds `100.100.100.100:53` for
  MagicDNS. Binding the box's own tailnet address should not collide, but the
  inventory captured no listening-port dump, so this is unverified. If it does
  collide, that is a finding worth recording — the fallback is binding
  `192.168.1.195:53` and accepting LAN exposure of the resolver.
- **Prove resolution from the box**, before touching the tailnet config:
  `dig @100.126.56.26 anything.rbrb.in` returns `100.126.56.26`, and
  `dig @100.126.56.26 example.com` still resolves normally.

**This ticket does not change what any client resolves.** The resolver sits
there answering nobody until [18](18-tailnet-split-dns.md) points the tailnet at
it — which is the safe ordering, and why 18 is blocked by this.

**Not blocked on [16](16-deploy-caddy.md).** CoreDNS can answer for
`*.rbrb.in` before Caddy exists; the name simply resolves to a box with nothing
listening on 443. Doing 16 first is sensible but is not a dependency.

Blocked by [07](07-repo-layout-and-conventions.md) for where the files live and
what a service declaration looks like, and [11](11-stand-up-komodo.md) because
Komodo must exist to deploy anything.

Resolved when `dig @100.126.56.26 <anything>.rbrb.in` answers `100.126.56.26`
from the box, and the stack — Corefile, compose, Komodo Stack TOML — reproduces
from the repo.

## Settled by [07](07-repo-layout-and-conventions.md)

- The Corefile is `stacks/coredns/Corefile`, beside the compose file, and
  bind-mounted in.
- `stacks/coredns/komodo.toml` holds the `[[stack]]`; `project_name = "coredns"`.
- The explicit host bind is written as a full
  `<host-ip>:<host-port>:<container-port>` publish —
  `"100.126.56.26:53:53/udp"` and the `/tcp` pair. 07 accommodated this rather
  than forcing a uniform port convention on it.
- No secrets, so `pre_deploy` is the bare `shared`-network create.

## Resolution

CoreDNS 1.14.6 is live on `100.126.56.26:53`, udp and tcp, and answers every
`rbrb.in` name with tower's tailnet address. `stacks/coredns/` reproduces it from
the repo; `coredns` is in the `BatchDeployStackIfChanged` list.

Verified from a machine off both networks, over the tailnet:

| | |
|---|---|
| `home.rbrb.in`, `sonarr.rbrb.in`, the apex, `a.b.c.rbrb.in` | all `100.126.56.26` |
| `AAAA` | `NOERROR`, `ANSWER: 0` — NODATA, not NXDOMAIN |
| `example.com` | `REFUSED` |
| TCP | answers |
| `dig @192.168.1.195` | no answer — it does not listen on rb's LAN |

End to end: following CoreDNS's answer reaches Caddy at HTTP 200 with the
trusted wildcard, in 30ms. **The chain is complete except for delivery** — no
client asks CoreDNS anything until [18](18-tailnet-split-dns.md) lands.

### The question was reopened before it was built

The human stopped the session to ask whether CoreDNS was needed at all, since
the public record already covers rb's network and a pihole entry could cover the
home network. Laid out, the two options are **identical everywhere except one
row**: a device on neither network — a laptop tethered in a café, a phone on
cellular — has no pihole and no route to `192.168.1.195`. Only Split DNS reaches
it.

**Ruling: roaming is in scope**, and it is the entire justification for CoreDNS
over a pihole record. Both options put one record in state git does not own, so
that is a wash and not a tiebreaker. If roaming is ever dropped from the
destination, this Stack has no remaining reason to exist.

### Three departures from what this ticket wrote down

- **The Corefile is `conf/Corefile`**, not beside the compose file as 07 settled.
  [16](16-deploy-caddy.md) found a single-file bind goes ESTALE on the next git
  pull, silently. `docs/conventions.md` already said so; this ticket predated it.
- **`.` REFUSEs rather than forwarding.** Split DNS is *restricted to a domain*,
  so a client sends only `rbrb.in` here and keeps its own resolver for everything
  else — pihole at home, rb's router on rb's network, DHCP's when roaming. The
  `.` block is therefore unreachable in normal operation, and refusing keeps that
  true instead of quietly becoming a general resolver on the tailnet. This ticket's
  `forward . /etc/resolv.conf` was wrong regardless: inside a container that file
  is `127.0.0.11`, docker's embedded DNS.
- **No PUID/PGID.** The image is `nonroot:nonroot` fixed at build, takes no such
  env, and needs `-conf /etc/coredns/Corefile` explicitly — its default config
  path is `./Corefile`.

### Findings

- **No port collision, and the risk was never real.** Nothing binds `:53` on the
  box at all. `tailscaled` takes `100.100.100.100:53` only when a device has
  `--accept-dns=true`, and tower has it **off** — and that is a different address
  in any case. The fallback to `192.168.1.195:53` is not needed.
- **Boot-order hazard, new.** Docker cannot bind `100.126.56.26:53` before
  `tailscale0` is up, so a reconcile racing a reboot fails until
  `restart: unless-stopped` catches up. Recorded in the compose file. It is a
  candidate symptom for [29](29-alerting-on-failed-reconcile.md).
- **A source-IP `view` would force host networking.** A device on rb's network
  that also joins the tailnet with `--accept-dns=true` would get
  `100.126.56.26` and reach tower over WireGuard rather than straight across the
  LAN. Today only tower is in that position and its `--accept-dns` is off, so it
  is moot. The fix, if it ever matters, is CoreDNS's `view` plugin keyed on
  client IP — which cannot work behind a published port, because
  [16](16-deploy-caddy.md) proved tailnet clients arrive masqueraded as the
  bridge gateway. It would have to be host-networked, like Caddy.
