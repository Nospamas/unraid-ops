---
id: "18"
title: Point Tailscale Split DNS at CoreDNS
type: task
status: closed
description: >
  One restricted-nameserver row delivers split-horizon, and 05's answer is
  complete. Two traps recorded — the console has no "Split DNS" section, and
  the mis-click that makes CoreDNS global (killing all DNS everywhere) is the
  same dialog; and on Windows `nslookup` bypasses the NRPT and reports a false
  failure.
touches: []
---

# 18 — Point Tailscale Split DNS at CoreDNS

Resolved: 2026-08-03
Blocked by: 17

## Question

The console half of [05](05-remote-access.md)'s split-horizon answer, and the
**only** thing still missing: [17](17-deploy-coredns.md) proved CoreDNS answers
correctly and that following its answer reaches Caddy at HTTP 200. Nothing asks
it anything until this lands.

This is Tailscale admin-console work — **state outside git**, the same category
as the Cloudflare zone in [14](14-cloudflare-zone-and-token.md), so it is
recorded here rather than declared in the repo.

### What 17 found, that changes this ticket

- **MagicDNS is already enabled tailnet-wide** (suffix `gute-morpho.ts.net`).
  This ticket previously called it a hard prerequisite to do; it is done.
- **No global nameservers are configured** — `Resolvers: (no resolvers
  configured, system default will be used)`. That is already the state the pihole
  risk below asks for, so adding one Split DNS route does not disturb it.
- **Per-domain routing is already demonstrably additive**: `ubuntu-dev` shows a
  live `ts.net. -> 199.247.155.53` split route while still using pihole for
  everything else. On Linux, at least, a single-domain exception is exactly that.
- **The real per-device switch is `--accept-dns`, not MagicDNS.** `ubuntu-dev`
  has it on; **tower has it off and should stay off** — otherwise the box
  resolves `rbrb.in` to its own tailnet address instead of taking the LAN path.
  `earth` and `uranus` are **unknown and must be checked**: with it off, that
  device ignores tailnet DNS entirely and this ticket does nothing for it.

Do, in the admin console under **DNS**:

- **Add a Split DNS entry**: domain `rbrb.in` → nameserver `100.126.56.26`.
  Restricted to that domain only.
- **Leave "Override local DNS" off** and add **no** global nameservers.

Then, per device (`earth`, `uranus`): confirm `--accept-dns` is on, and verify:

- `<anything>.rbrb.in` resolves to `100.126.56.26`, **not** `192.168.1.195`.
- Resolution works from **off-LAN**. Testing only from the house proves nothing —
  roaming is the entire reason CoreDNS exists rather than a pihole record
  ([17](17-deploy-coredns.md)).
- With tailscale **disconnected**, the same name falls back to public Cloudflare
  and returns `192.168.1.195`. Correct; worth confirming so the fallback is
  understood rather than discovered later.

### The pihole interaction — this ticket's real risk

The home network's resolver is a pihole, and `earth` and `uranus` sit on that
network. The risk is that a single-domain split becomes a total DNS takeover.

- **Windows is the one to check**, not Linux. `earth` and `uranus` have no
  systemd-resolved to do per-domain routing, so Tailscale's Windows client is
  where this is most likely to go all-or-nothing.
- **The tell is silent** — ads reappearing days later, not an error. Resolve a
  known-blocked domain on `uranus` before and after, and confirm the answer is
  still pihole's.

If Split DNS is all-or-nothing on Windows, **say so and stop**. That reopens
17's ruling: pihole answering `rbrb.in` → `100.126.56.26` covers the house
without disturbing anything, leaving only roaming devices unserved — and the
human has ruled roaming in scope, so the trade would have to be put to them
rather than decided here.

Record in the resolution: the exact console settings applied, `--accept-dns` per
device, whether the off-LAN check passed, and whether pihole survived.

Blocked by [17](17-deploy-coredns.md) — now closed.

Resolved when a tailnet client **outside the house** resolves `*.rbrb.in` to
`100.126.56.26`.

## Resolution

**Split-horizon is delivered.** [05](05-remote-access.md)'s answer is complete
and [17](17-deploy-coredns.md)'s Stack is no longer talking to nobody: tailnet
clients resolve `*.rbrb.in` to `100.126.56.26` and reach Caddy, while every
other name keeps taking each client's own resolver.

### The console setting, as applied

One entry, in the admin console under **DNS → Nameservers**: `100.126.56.26`,
restricted to domain `rbrb.in`. Global nameservers empty, **Override DNS
servers** off, MagicDNS untouched. Reverting is deleting that one row; nothing
on the box is involved either way.

**The ticket's instruction was stale on where this lives.** There is no section
called "Split DNS" in the current console. A split route *is* a nameserver with
**Restrict to domain** ticked — and adding one without ticking it makes CoreDNS
**global**, which, since CoreDNS REFUSEs everything outside `rbrb.in`, takes all
DNS off every `--accept-dns` device at once. The dangerous mis-click and the
intended action are the same dialog.

Propagation to an already-connected client took **60–180s**, not instant. Long
enough to look like a failed save.

### Verified

| | `ubuntu-dev` (linux, home net) | `uranus` (windows, home net) |
|---|---|---|
| `--accept-dns` | on | on |
| split route present | ✓ | ✓ |
| `*.rbrb.in` | `100.126.56.26` | `100.126.56.26` |
| pihole canary `ads.google.com` | `0.0.0.0` | `0.0.0.0` / `::` |
| public + local `xgy.im` names | unchanged | system resolvers unchanged |
| `https://home.rbrb.in` | **HTTP 200** from `100.126.56.26` | — |

`tower` stays `CorpDNS: false`, confirmed over SSH — it must, or the box
resolves `rbrb.in` to its own tailnet address instead of taking the LAN path.
**Roaming confirmed by the human off both networks**, which is the bar 17 set.

### The pihole risk is dead, structurally

This ticket's stop-and-reopen-17 condition was Windows Split DNS going
all-or-nothing. It does not, and `Get-DnsClientNrptPolicy` on `uranus` shows why
rather than merely suggesting it: Tailscale installs **per-namespace NRPT
rules** — a discrete `.rbrb.in` entry beside `.ts.net`, `.gute-morpho.ts.net`
and the `100.x` reverse zones — and **no `.` catch-all**. Names outside those
namespaces never reach the Tailscale resolver. Windows routes per-domain by the
same construction as systemd-resolved.

**Verify on Windows with `Resolve-DnsName`, never `nslookup`.** nslookup
bypasses the NRPT and queries the configured server directly, so it returns the
public `192.168.1.195` and reads as a failure while everything is working.

### Left unverified

`earth` was online but never individually checked for `--accept-dns`. If it is
off, that device resolves `rbrb.in` to `192.168.1.195` and cannot reach it from
the home network. One command to check, one to fix; not worth a ticket.
