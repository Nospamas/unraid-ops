# 18 — Point Tailscale Split DNS at CoreDNS

Type: task (HITL)
Status: open
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
