# 18 — Enable MagicDNS and point Split DNS at CoreDNS

Type: task (HITL)
Status: open
Blocked by: 17

## Question

The console half of [05](05-remote-access.md)'s split-horizon answer. This is
Tailscale admin-console work — **state outside git**, the same category as the
Cloudflare zone in [14](14-cloudflare-zone-and-token.md), so it is recorded here
rather than declared in the repo.

Do, in the Tailscale admin console under **DNS**:

- **Enable MagicDNS.** It is a hard prerequisite — Split DNS is delivered to
  clients *through* MagicDNS, so with it off, clients ignore tailnet DNS config
  entirely.
- **Add a Split DNS entry**: domain `rbrb.in` → nameserver `100.126.56.26`.
  Restricted to that domain only; the tailnet's general DNS is untouched.

Then verify from a tailnet client, ideally `uranus` (the active Windows node):

- `<anything>.rbrb.in` resolves to `100.126.56.26`, **not** `192.168.1.195`.
- Resolution still works from **off-LAN** — that is the whole point of the
  ticket, and testing only from the house proves nothing.
- With tailscale **disconnected**, the same name falls back to public Cloudflare
  and returns `192.168.1.195`. Correct behaviour, worth confirming so the
  fallback is understood rather than discovered later.

**Expect a visible side effect on every tailnet device.** Enabling MagicDNS
routes client DNS through `100.100.100.100` and adds a `ts.net` search domain to
`earth` and `uranus`. Benign, but it is a change to machines that are not the
box, so it is worth knowing before rather than after.

Record in the resolution: the exact console settings applied, and whether the
off-LAN check actually passed.

Blocked by [17](17-deploy-coredns.md) — pointing Split DNS at a nameserver that
is not yet running would break `rbrb.in` resolution for every tailnet client
rather than fix it.

Resolved when a tailnet client **outside the house** resolves `*.rbrb.in` to
`100.126.56.26`.
