# 32 — Decide how rb's LAN resolves `rbrb.in`

Type: grilling
Status: open

## Question

Graduated out of the map's fog by [29](29-alerting-on-failed-reconcile.md),
which stopped it being hypothetical: **the LAN half of split-horizon has never
worked, and nothing had ever exercised it.**

[05](05-remote-access.md) leans on Cloudflare's public record *being* the view
on rb's network — "conveniently, there is no custom resolver to configure and
none is needed". That premise is false. rb's router at `192.168.1.254` strips
answers in `192.168.0.0/16` and returns `NOERROR` with no answer, so no device
using it resolves any `rbrb.in` name.

It is **not** generic rebind protection and **not** DNSSEC. Measured with
`nip.io`, which resolves arbitrary addresses:

| name | via router | public |
|---|---|---|
| `1-1-1-1.nip.io` | 1.1.1.1 | 1.1.1.1 |
| `10-0-0-1.nip.io` | 10.0.0.1 | 10.0.0.1 |
| `172-16-0-1.nip.io` | 172.16.0.1 | 172.16.0.1 |
| `192-168-1-1.nip.io` | **empty** | 192.168.1.1 |

Only the router's own LAN range is filtered. `localtest.me` → `127.0.0.1`
passes, and `dig +cd` changes nothing.

Why it went unnoticed: every verification this map has done came from the
tailnet. `ubuntu-dev` has `--accept-dns` on, so it resolves via CoreDNS and
never touches rb's router. tower is the first thing to ask that router for an
`rbrb.in` name.

The human has stated the requirement: **non-tower devices must resolve via the
`192.168.1.254` route.** So "use the tailnet" is not an answer here, though it
remains the answer for roaming.

### What has to be decided

- **Which mechanism.** Three are known, and they trade differently:

  | | cost |
  |---|---|
  | router hands out CoreDNS as the DHCP DNS server | CoreDNS must also bind `192.168.1.195:53` and **stop REFUSEing `.`**, which [17](17-deploy-coredns.md) chose deliberately. The box becomes rb's resolver: box down = rb's internet DNS down. |
  | the router's static-hostname table, if it has one | no single point of failure, no CoreDNS change. A row per service, no wildcard, and it is host state git cannot own [26](26-host-state-scope.md). |
  | per-device DNS override | no SPOF. Manual per device, and no help for a TV, printer or guest. |

  The router is the newer TELUS gateway, not the Actiontec T3200M — generic
  nginx login page, model not identified. Whether it exposes a static-hostname
  table is **unknown and must be checked before this is decided**; it changes
  which options are live.

- **Whether CoreDNS should serve rb's LAN at all.** This is the real question
  behind the first. [17](17-deploy-coredns.md) built a resolver that answers
  one domain and REFUSEs everything else, precisely so it could never become a
  dependency for general internet access. Serving rb's LAN reverses that on a
  box that reboots for deploys. **Say whether that is acceptable rather than
  letting the mechanism choice imply it.**

- **What [05](05-remote-access.md) should have said.** Its reasoning needs
  correcting on the record, not quietly working around. The same goes for the
  map's two-networks table, which lists rb's resolver as "none of ours" as
  though that were sufficient.

- **Whether this changes the destination.** "Reachable from outside the house"
  is met. Reachable *inside* rb's house, by a device that is not on the tailnet,
  is arguably a separate promise this map never made explicitly — and ruling it
  out of scope is a legitimate answer, though the human has asked for it.

### What is already betting on this

[29](29-alerting-on-failed-reconcile.md) set `KOMODO_HOST=https://komodo.rbrb.in`
so that alert links resolve correctly on both sides of the split rather than
being hardcoded to one. **Half of that bet is currently unpaid**: on rb's LAN
the link does not resolve, and will not until this ticket lands. It works from
the tailnet today, which is where alerts are read, so this is a reason to
resolve 32 rather than to revert 29.

Not a lockout risk on its own, but the first option touches DNS for rb's whole
household. **State the rollback before changing what the router hands out.**
