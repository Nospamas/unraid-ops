---
id: "01"
title: Inventory the containers already running on the box
type: task
status: closed
description: >
  The box as found, in assets/01-inventory.md: no compose on the host, already
  two-tier under Portainer and the Docker tab, the gluetun sidecar already in
  place, every image `latest`, PUID/PGID diverging three ways, and no homepage
  at all.
touches: []
---

# 01 — Inventory the containers already running on the box

Resolved: 2026-08-01
Asset: [assets/01-inventory.md](../assets/01-inventory.md)

## Question

Nothing here is a decision — but every decision downstream is blocked until we
can see what we are adopting. Capture the current state of the unraid box as a
committed markdown asset.

**HITL**: there is no agent access to the box — the human drives it through the
Web UI over tailscale (see the map's Box access note). So this ticket is worked
as a hand-off: the session writes a copy-pasteable command checklist, the human
runs it and pastes the output back, and the session turns that into the asset.
Write the checklist to be run in one sitting, in the Web UI's terminal, with the
commands ordered so the output can be pasted back in one block.

Capture:

- Every running container: name, image, exact tag, restart policy.
- Port mappings, and which are exposed to the LAN.
- Every volume mount, with the host path on the array (`/mnt/user/...`) and
  the container path — especially the appdata directory for each service.
- Environment variables, with secret-looking values redacted to a placeholder
  and noted as "needs a secret" rather than copied.
- Which network each container is on, and whether any already route through a
  VPN container.
- The unraid docker template XML for each service
  (`/boot/config/plugins/dockerMan/templates-user/*.xml`) — these hold the
  original Community Apps definitions and are the raw material for translating
  into compose.
- Unraid version, Docker version, and whether the Compose Manager plugin is
  installed.

The answer records the asset's path plus the handful of facts later tickets will
lean on: appdata root, the box's LAN address, its tailscale hostname (ticket 05
will care), and which services are already VPN-routed.

## Resolution

Captured in two passes — the first template blew up on `.HostConfig.Sysctls`
(Docker 27 omits absent map keys and `docker inspect --format` treats that as
fatal), so section 5 was re-run without it. Asset:
[assets/01-inventory.md](../assets/01-inventory.md), raw output alongside it.

Facts later tickets lean on:

- **appdata root** `/mnt/user/appdata`, media root `/mnt/user/Media`
  (`books downloads movies music-rb music-reg podcasts temp tv`).
- **LAN** `192.168.1.195`, **tailscale** node `tower` = `100.126.56.26`,
  hostname `Tower`.
- **Unraid 7.3.2, Docker 29.5.3, no `docker compose` on the host.** No Compose
  Manager, no User Scripts plugin. Nothing on the box speaks compose except
  Portainer, internally. (Captured at 7.2.0 / 27.5.1; the box was upgraded
  before [11](11-stand-up-komodo.md)'s bootstrap and re-verified there —
  **the absent compose plugin is unchanged**, so nothing downstream moves.)
- **The box is already two-tier**: Portainer runs `plex` (stack 1) and
  `gluetun`+`qbittorrent` (stack 2) from compose files under
  `/mnt/user/appdata/portainer/compose/`; the unraid Docker tab runs `sonarr`,
  `radarr`, `prowlarr`, `calibre`, `lazylibrarian`, `PortainerCE`. Three of the
  eight in-scope workloads therefore already have compose definitions to lift;
  only five need translating from template XML. There is no plex template.
- **VPN-routed**: `qbittorrent` only, via `network_mode: service:gluetun` — the
  sidecar pattern ticket 06 was going to propose is already in place. Provider
  is **NordVPN/WireGuard**, which has **no port forwarding**
  (`VPN_PORT_FORWARDING=off`), so seeding is already crippled by provider
  choice, not by topology.
- The *arr services are on the default `bridge` network and gluetun is on
  `qbittorrent_default`, so **qbittorrent is only reachable via the host**
  at `192.168.1.195:30024`.
- **Every image is `latest` and 5–8 months stale.** Nothing auto-updates.
- **PUID/PGID diverge three ways** — qbittorrent writes downloads as 1001:1001,
  the *arr read them as 99:100 with `UMASK=022`, plex is 1000:1000. Split out as
  ticket 09.
- **Homepage does not exist on the box.** Ticket 08 is a greenfield deploy, not
  a migration; renamed accordingly.

Two secrets leaked through the probe's redactor and were scrubbed from the repo:
the calibre GUI password (XML `Mask="true"` element text) and the NordVPN
WireGuard private key (YAML `KEY: "value"`). The redactor now covers all three
shapes. **Rotation was ruled not worth doing** — both are low-severity and were
already plaintext on the box; see the map's Secret severity note.
