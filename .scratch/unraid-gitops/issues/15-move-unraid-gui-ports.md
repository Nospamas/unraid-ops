# 15 — Move the Unraid Web GUI off ports 80/443

Type: task (HITL)
Status: open
Assignee: Nospamas

## Question

Surfaced by [04](04-reverse-proxy-and-domain.md). Unraid's own nginx holds host
ports **80 and 443** by default, so Caddy cannot bind them while the GUI is
where it is. The human chose to move the GUI rather than give Caddy its own LAN
IP on `br0` — macvlan and ipvlan both isolate the container from the host, which
would have stopped Caddy reaching the bridge-network services at
`192.168.1.195:<port>`.

Note [01](01-inventory-running-containers.md) never captured host listening
sockets, so **confirm what actually holds 80/443 before changing anything** —
the default is assumed, not observed.

Do:

- Confirm the current state: what is listening on 80 and 443 on the host, and
  whether Unraid's SSL is on or off (it decides whether 443 is even in use).
- **Settings → Management Access**: HTTP port `80` → `8008`, HTTPS port `443` →
  `8443`.
- Re-establish access on the new port and confirm the GUI still answers over
  **tailscale** as well as the LAN — the human's only path to the box is the Web
  UI over tailscale, so getting this wrong is the one change here that can lock
  them out.
- Confirm 80 and 443 are now free.

**Small but not safe**: this is the one ticket that can cost access to the box.
Do it while the tailscale path is known-good, and know the new URL before
saving.

**HITL**: box change, human-driven, per the map's Box access note.

Blocks [16](16-deploy-caddy.md) — Caddy cannot bind 80/443 until this is done.
Independent of everything else, so it can run whenever.
