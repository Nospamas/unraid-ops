---
id: "43"
title: Probe home-ops from tower, closing the box-down gap
type: task
status: closed
description: >
  Three gatus probes at home-ops — its ntfy and gatus over the tailnet, and the
  same gatus again through Cloudflare — alerting to tower's own ntfy, with no
  cross-site credential. The names needed two narrow CoreDNS zones rather than a
  blanket forward, because `.` must keep answering REFUSED.
touches: [stacks/gatus/, stacks/coredns/, .renovaterc.json5]
---

# 43 — Probe home-ops from tower, closing the box-down gap

Resolved: 2026-08-06
Blocked by: [29](29-alerting-on-failed-reconcile.md), and on home-ops landing
its half — which it has

## Question

[29](29-alerting-on-failed-reconcile.md) built tower's alerting and left one
thing open, in its own words: **box-down**. ntfy and gatus both die with tower,
so silence stays indistinguishable from health, and self-hosting made that
*worse* than a third party would have — the notification server is now part of
the outage.

29 settled the shape rather than fogging it: **each site runs its own ntfy,
alerts to its own, and probes the other.** The phone subscribes to both. No
cross-site credential, because neither site ever writes to the other's ntfy —
only reaches it.

tower's half was built and waiting. home-ops's did not exist, because the Talos
cluster was not on the tailnet. It is now, and home-ops has landed its side and
handed over a brief with addresses. This ticket is the mirror image: tower's
gatus probes home-ops, alerting to tower's own ntfy.

## Answer

**Three probes and two CoreDNS zones.** Connectivity was never the problem; the
names were.

| probe | path | threshold |
|---|---|---|
| home-ops ntfy | `http://ntfy.gute-morpho.ts.net/v1/health` | 2m × 5 ≈ 10 min |
| home-ops gatus | `http://home-ops-gatus.gute-morpho.ts.net/health` | 2m × 5 ≈ 10 min |
| home-ops via cloudflare | `https://status.xgy.im/health` | 2m × 10 ≈ 20 min |

Longer than the 60s × 3 every local probe uses [29], because these cross the
open internet and a transient WAN blip is not home-ops dying. The tailnet pair
matches what home-ops runs against tower; the Cloudflare probe is longer again,
having two more third parties in its path.

### The hand-off's premise about names was wrong, and it was this repo's fault

The brief assumed its `curl http://ntfy.gute-morpho.ts.net/...` would work from
tower. Nothing about it does, for two independent reasons:

- **tower runs `--accept-dns=false`** (`CorpDNS: false`), so MagicDNS resolves
  nowhere on the box. `/etc/resolv.conf` is `1.1.1.1`/`8.8.8.8` and every
  `ts.net` name is NXDOMAIN. `100.100.100.100` answers correctly, but only if
  asked by address.
- **gatus is pinned to CoreDNS and nothing else** [29, 32], and CoreDNS REFUSEs
  every name outside `rbrb.in` [17]. All three targets came back REFUSED.

That second one is the real constraint, and
[gatus's compose](../../../stacks/gatus/compose.yaml) had already written down
why it had never bitten: the Stack survived "only because every other address in
this Stack is a literal IP".

**Connectivity was fine throughout.** Every endpoint answered 200 by address on
the first attempt, `tailscale ping` was direct at 4ms, and the tailnet ACL the
brief suspected needed nothing. The whole failure was resolution.

### Two narrow zones, not a blanket forward

```
gute-morpho.ts.net { forward . 100.100.100.100 }
xgy.im             { forward . 1.1.1.1 }
.                  { REFUSED }          # unchanged
```

`.` must keep answering REFUSED, and not only for [17]'s reason that a
misconfiguration should be loud. **An `rbrb.in` name reaching a public resolver
gets `192.168.1.195`** — the LAN path, where the *arr disable auth for local
addresses and answer 200 where [29]'s probes assert 302. A blanket forward would
have quietly rewritten the meaning of ten existing probes.

Rejected: **literal IPs**, the convention everywhere else in that Stack. These
are Tailscale Kubernetes operator devices, recreated with fresh addresses when
the operator reconciles them, and `status.xgy.im` is Cloudflare anycast — it
cannot be an address at all. The zone forward survives both.

CoreDNS is on the `shared` bridge, not host-networked, so that it can reach
`100.100.100.100` was verified from a bridge container before the Corefile was
written, not assumed.

### Why the public probe earns its place

It is the *same* gatus as the tailnet probe, reached the long way round. That
makes it a different question, and the pair localises the fault:

| tailnet | cloudflare | meaning |
|---|---|---|
| fail | fail | home-ops or its WAN link is down |
| **pass** | **fail** | cluster fine; Cloudflare or the Tunnel broken — nothing else sees this from outside |
| **fail** | **pass** | home-ops fine; *tower's* tailnet path is broken |
| pass | pass | healthy |

The third row is the one that pays: it stops a DERP or WAN blip on tower's side
reading as "home-ops is down". Its alert is worded **"not reachable from the
internet"** rather than "down", because those need different responses.

**All three share one group.** The brief proposed a separate
`home-ops-external` group and this ticket rejected it: a gatus group is display
only, and what separates the two questions is the alert — its own threshold, its
own wording, fired independently. The table above survives the merge; it just
is not drawn on the status page. Note that regrouping **rekeys** an endpoint and
discards its history.

### No ICMP probe

The brief suggested one, correctly noting that home-ops cannot do it in its
direction — its probes traverse an L4 `ExternalName` Service — while tower runs
tailscale on the host and could.

It cannot. **`net.ipv4.ping_group_range` is `1 0`** on this box, an empty range,
so gatus at `99:100` cannot open an unprivileged ICMP socket. Widening it is
host state [26] bought for a signal already redundant with two HTTP probes that
fail together whenever the path does. Dropped, not deferred.

### [29]'s Renovate carve-out retired, on its own condition

29 made `stacks/ntfy/**` and `stacks/gatus/**` human-merge "because nothing on
tower watches the watcher", and said explicitly: **"That retires when home-ops
probes tower."** home-ops now probes both. The rule was removed rather than
re-argued — it was written with its own expiry.

### Verified

CoreDNS and gatus both restarted clean; all three new probes pass; **all 17
endpoints green**, which is the evidence that the Corefile change leaked no
`rbrb.in` name to a public resolver — the ten existing probes still assert their
tailnet status codes and still pass.

Two of the brief's own verification steps could not run and were replaced:
`docker exec … wget` has no shell to find, the gatus image being distroless, and
the host `curl`s fail on the MagicDNS problem above. The question "can gatus
resolve this" was answered by querying its sole resolver directly instead.

**Not proven: that these alerts fire.** The gatus→ntfy path itself was proven in
[29], and these use the same provider and mechanism, but proving *these* needs a
deliberate outage — see below.

## Hand-offs

- Run the failure injection: block tower's route to `100.111.77.118` for ~12
  minutes, or have home-ops scale ntfy to zero. Until then the box-down alert is
  configured but unproven, which is the failure mode [29] exists to prevent.
- Break only `status.xgy.im` with the tailnet probes green, and confirm the
  Cloudflare alert fires alone. The shared group means the status page will not
  show this — check which notification arrives.
- Confirm the phone's tower ntfy subscription is live. No probe can test it.
- Tell home-ops its brief's verification commands do not run against tower, so
  the next hand-off does not repeat it.
