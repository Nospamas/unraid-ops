# 17 — Deploy CoreDNS for the tailnet view

Type: task
Status: open
Blocked by: 07, 11

**The LAN half already works and this ticket must not touch it.** The LAN's
resolver is a pihole in `~/home-ops`; it only has to forward `rbrb.in` upstream
to Cloudflare's public `*.rbrb.in` → `192.168.1.195`, which
[16](16-deploy-caddy.md) confirmed Caddy answers. Adding `rbrb.in` records to
pihole would be a second implementation of the same view. **CoreDNS serves the
tailnet only** — that is the whole point of binding `100.126.56.26:53`.

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
