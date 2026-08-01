# 06 — Decide the qbittorrent VPN topology

Type: research
Status: open

## Question

**The topology question is largely already answered.**
[01 — Inventory the containers already running on the box](01-inventory-running-containers.md)
found the gluetun sidecar pattern already running: `qbittorrent` has
`network_mode: service:gluetun`, gluetun holds `CAP_NET_ADMIN` and publishes the
WebUI on host port 30024 and torrent traffic on 6881 tcp+udp. The alternatives
originally listed here — a VPN-enabled qbittorrent image, host-level routing —
would be a *regression* from what exists. Adopt the existing topology unless
something below forces otherwise.

What actually remains open:

- **The provider.** It is NordVPN over WireGuard, pinned to `us8240.nordvpn.com`
  (Seattle), with `VPN_PORT_FORWARDING=off`. NordVPN offers no port forwarding
  at all, so **seeding is already crippled and no config change fixes it** — the
  only fix is a different provider (ProtonVPN, AirVPN and PIA are the usual
  port-forwarding options, all supported by gluetun). Decide whether that
  matters enough to switch. This is now the ticket's central question, and it is
  a judgement call about ratio and tracker requirements, not a technical one.
- **How the *arr services reach qbittorrent.** Today they cannot do it by
  container name: sonarr/radarr sit on the default `bridge` network
  (172.17.0.0/16) while gluetun is on `qbittorrent_default` (172.18.0.0/16), so
  the only path is the host at `192.168.1.195:30024`. Decide whether the repo
  encodes that host-IP indirection, or puts the *arr on a shared user-defined
  network with gluetun so a container name resolves. The latter is tidier and
  removes a hard-coded LAN address from git.
- **Two firewall variables in the running stack look like no-ops.**
  `FIREWALL_VPN_INPUT_ALLOW=192.168.1.0` and `FIREWALL_OUTBOUND_SUBNET=0.0.0.0/0`
  are set, but gluetun's real variables (`FIREWALL_INPUT_PORTS`,
  `FIREWALL_OUTBOUND_SUBNETS` — plural) are empty in the container's actual
  environment. Confirm against gluetun's docs before the repo copies them
  forward; if they are typos, the current kill-switch posture is not what was
  intended.
- **Kill-switch behaviour** — what happens to torrent traffic when the tunnel
  drops. `FIREWALL_ENABLED_...=on` and `HEALTH_RESTART_VPN=on` are set; confirm
  that qbittorrent cannot leak during a gluetun restart, given it shares the
  namespace.
- **Whether the proxy from ticket 04 can reach the WebUI** through the same
  indirection. Note the WebUI currently binds `0.0.0.0:30024` with no auth in
  front of it beyond qbittorrent's own.
- The stale `ghcr.io/bubuntux/nordvpn:get_private_key` image on the box is
  leftover key-generation tooling; note whether anything still needs it.

Write the comparison as an asset only where a real choice remains — chiefly the
provider. The answer names the provider, whether port forwarding is being bought,
and how the *arr address qbittorrent.
