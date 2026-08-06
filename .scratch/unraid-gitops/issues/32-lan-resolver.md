# 32 — Decide how rb's LAN resolves `rbrb.in`

Type: grilling
Status: closed

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

## Resolution (2026-08-05)

**One router field, and no repo change.** DHCP Settings → DNS server =
`1.1.1.1, 8.8.8.8` on the NH20T, applied by rb. Devices ask past the router
instead of through it, so 04's public record finally *is* the LAN view. CoreDNS
stays exactly as [17](17-deploy-coredns.md) built it, tower never becomes rb's
resolver, and the single point of failure every option below traded against
never gets created.

It works because **the router does not intercept outbound port 53** — only its
own forwarder strips the answer. Measured from tower on rb's LAN, 2026-08-04
and re-measured 2026-08-05:

| name | via `192.168.1.254` | via `1.1.1.1` / `8.8.8.8` |
|---|---|---|
| `192-168-1-1.nip.io` | empty | 192.168.1.1 |
| `sonarr.rbrb.in` | empty | **192.168.1.195** |
| `example.com` | resolves | resolves |

**The LAN path is verified end to end**, not just the DNS half: resolved at
`192.168.1.195`, `https://sonarr.rbrb.in` and `https://komodo.rbrb.in` both
answer **200**, so the `(internal)` guard admits a LAN source and
[29](29-alerting-on-failed-reconcile.md)'s unpaid half — `KOMODO_HOST` links
that did not resolve on rb's LAN — is paid.

Cost: the router's `lan` domain stops resolving for every device, since none of
them ask the router any more. mDNS discovery is unaffected. Rollback is
restoring `192.168.1.254` in the same field, bounded by DHCP lease renewal, and
no worse than today's state meanwhile.

**tower is exempt by construction, and stays exempt.** `network.cfg` carries
`DHCP_KEEPRESOLV="yes"` and `DNS_SERVER1="192.168.1.254"`, and `rc.inet1` starts
dhcpcd with `-C resolv.conf`, so the box ignores the DHCP DNS option entirely —
`/etc/resolv.conf` still reads `nameserver 192.168.1.254` and **the box still
resolves no `rbrb.in` name**. That is a standing property rather than a
leftover: anything running on the box that needs one must be handed CoreDNS
explicitly, as gatus is. Now a rule in
[docs/conventions.md](../../../docs/conventions.md), Addressing.

**Not verified here**: the DNS option the router actually offers. tower is the
only LAN device this session can reach and it ignores that option by
construction, so confirmation is one lookup on a non-tower LAN device.

### The other questions

- **Which mechanism.** None of the three. Each moved the *answer*; this moves
  *who is asked*, which none of them considered. Conditional forwarding was
  ruled out on 2026-08-04 (fixed DNS Set dropdown), and the rebind-toggle
  option was never needed — it is not rebind protection.
- **Whether CoreDNS should serve rb's LAN.** **No.** 17's answer-one-domain,
  REFUSE-the-rest design stands untouched. Box down means no `rbrb.in` on rb's
  LAN, never no internet.
- **What [05](05-remote-access.md) should have said.** Corrected on 05 and in
  the map's two-networks table: rb's router is not merely "none of ours", it
  strips `192.168.0.0/16` answers, so the public record was never the LAN view
  while devices asked that router.
- **Whether this changes the destination.** No. In scope, and delivered.

### Do not probe DHCP from tower

`dhcpcd -T eth0` **segfaulted** — eth0 is enslaved to `br0`, which holds the
real lease — and left three orphan proxies whose kill took `/var/db/dhcpcd/`
with it. Directory recreated; br0 kept its address, route, gateway and WAN
throughout, and `192.168.1.195` is a reservation, so a renewal returns the same
address. The offered DNS option is not readable from the box anyway: dhcpcd runs
`-q -C resolv.conf` and logs nothing about it.

The options below are kept for the record; all are now moot.

### What has to be decided

- **Which mechanism.** Three are known, and they trade differently:

  | | cost |
  |---|---|
  | router hands out CoreDNS as the DHCP DNS server | CoreDNS must also bind `192.168.1.195:53` and **stop REFUSEing `.`**, which [17](17-deploy-coredns.md) chose deliberately. The box becomes rb's resolver: box down = rb's internet DNS down. |
  | the router's static-hostname table, if it has one | no single point of failure, no CoreDNS change. A row per service, no wildcard, and it is host state git cannot own [26](26-host-state-scope.md). |
  | per-device DNS override | no SPOF. Manual per device, and no help for a TV, printer or guest. |

  The router is the newer TELUS gateway, not the Actiontec T3200M:
  **Technicolor NH20T**, software `20.3.i.0565.7`. Whether it exposes a
  static-hostname table is **unknown and must be checked before this is
  decided**; it changes which options are live. Public material puts DNS in the
  gateway's DHCP widget rather than a separate WAN DNS page, and says nothing
  about static hostnames.

  **Conditional forwarding looked live and is not.** *WAN services → DNS &
  DynDNS → DNS rules* is a Domain/DNS Set table, but DNS Set is a fixed
  dropdown — `default`, `wan`, `wan6`, `wwan`, `lanwan`, `loopback_managed` —
  with no field for an arbitrary server. A rule can only steer a domain between
  the ISP's own resolvers, never at CoreDNS. Ruled out 2026-08-04.

  One thread left: *Local Network → DNS* shows the `lan` interface with **no
  dns server** while `lanwan` is selectable. If the LAN interface can be given
  a DNS server, `rbrb.in` → `lanwan` revives the approach. Unverified, and a
  long shot.

  A fourth option opens if the NH20T has a **rebind or DNS-security toggle**:
  disabling it makes the existing public record correct on rb's LAN with no
  repo change and no single point of failure. Check this before the other three.

  `192.168.1.195` is now a **DHCP reservation**, so every option below has a
  stable address to bet on.

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
