# 06 — Decide the qbittorrent VPN topology

Type: research
Status: open
Blocked by: 01

## Question

qbittorrent's traffic goes through a VPN. Settle the container topology:

- **Gluetun sidecar with `network_mode: service:gluetun`** — qbittorrent has no
  network of its own; the VPN container owns the stack. The common pattern.
- **A VPN-enabled qbittorrent image** (binhex, hotio) — fewer containers, less
  composable.
- **Host-level VPN routing** — heaviest, affects everything on the box.

Resolve alongside it:

- **Which VPN provider**, and whether it supports **port forwarding** — without
  it seeding is crippled, and provider support is the real constraint here.
- **How the *arr services reach qbittorrent's API** when it has no network
  namespace of its own — via the gluetun container's name and a published port.
- **Kill-switch behaviour** — what happens to torrent traffic when the tunnel
  drops, and whether the container should refuse to start without it.
- **Whether the proxy from ticket 04 can reach qbittorrent's web UI** through
  the same indirection.

Blocked on the inventory because the current qbittorrent setup may already have
a VPN arrangement worth keeping rather than replacing.
