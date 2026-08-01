# Inventory: the unraid box as found

Captured 2026-08-01 for [01 — Inventory the containers already running on the box](../issues/01-inventory-running-containers.md).
Raw probe output: [inventory.out](inventory.out), [inventory-part2.out](inventory-part2.out)
(both redacted). Probe scripts: [01-inventory.sh](01-inventory.sh),
[01-inventory-part2.sh](01-inventory-part2.sh).

## Host

| | |
|---|---|
| Unraid | 7.2.0, kernel 6.12.54-Unraid |
| Docker | 27.5.1 — **no `docker compose` plugin on the host** |
| Hostname | `Tower` |
| LAN | `192.168.1.195/24` on `br0` (macvlan-capable, but nothing uses it) |
| Tailscale | host plugin; node `tower` = `100.126.56.26` |
| appdata root | `/mnt/user/appdata` |
| Media root | `/mnt/user/Media` — `books downloads movies music-rb music-reg podcasts temp tv` |
| Shares | `Media`, `appdata`, `system` |

Plugins installed: `community.applications`, `dockerMan`, `dynamix*`,
`intel-gpu-top`, `tailscale`, `unassigned.devices*`, `zip_manager`,
`DiskSpaceManagement`.

**Not installed**: Compose Manager, User Scripts. There is no compose
implementation on the box at all — the only thing that speaks compose today is
Portainer, internally.

## Who manages what, today

The box is already split in two, which the map did not know when it was charted:

| Manager | Containers |
|---|---|
| **Portainer** (compose stacks under `/mnt/user/appdata/portainer/compose/`) | `plex` (stack 1), `gluetun` + `qbittorrent` (stack 2) |
| **unraid Docker tab** (`dockerMan`, templates in `/boot/config/.../templates-user/`) | `sonarr`, `radarr`, `prowlarr`, `calibre`, `lazylibrarian`, `PortainerCE` |

Consequences:

- There is **no `my-plex.xml`** anywhere on `/boot` — plex has no unraid
  template, because Portainer owns it.
- Three of the eight in-scope workloads (`plex`, `gluetun`, `qbittorrent`)
  **already have compose definitions** that can be lifted into the repo almost
  verbatim. Only five need translating from template XML.
- `restart:` differs by manager: Portainer's three are `unless-stopped`; the
  dockerMan five are `no` (unraid handles autostart itself). Moving to compose
  means every service needs an explicit restart policy.

## Containers

`PUID`/`PGID`/`TZ` as found — note the divergence, it is the sharpest problem here.

| Container | Image (all `latest`) | Net | Host ports | PUID:PGID | TZ |
|---|---|---|---|---|---|
| `plex` | `lscr.io/linuxserver/plex` | bridge | 32400 | 1000:1000 | America/Vancouver |
| `gluetun` | `qmcgaw/gluetun` | `qbittorrent_default` | 30024, 6881 tcp+udp | 1000:1000 | America/Vancouver |
| `qbittorrent` | `lscr.io/linuxserver/qbittorrent` | `service:gluetun` | *(via gluetun)* | 1001:1001 | UTC |
| `sonarr` | `lscr.io/linuxserver/sonarr` | bridge | 8989 | 99:100 | America/Los_Angeles |
| `radarr` | `lscr.io/linuxserver/radarr` | bridge | 7878 | 99:100 | America/Los_Angeles |
| `prowlarr` | `lscr.io/linuxserver/prowlarr` | bridge | 9696 | 99:100 | America/Los_Angeles |
| `calibre` | `lscr.io/linuxserver/calibre` | bridge | 8080, 8081, 8181 | 99:100 | America/Los_Angeles |
| `lazylibrarian` | `lscr.io/linuxserver/lazylibrarian` | bridge | 5299 | 99:100 | America/Los_Angeles |
| `PortainerCE` | `portainer/portainer-ce` | bridge | 8000, 9000 | — | America/Los_Angeles |

Every image is pinned to `latest`, and every local image is **5–8 months old** —
nothing is auto-updating today.

### Mounts

appdata is uniformly `/mnt/user/appdata/<service>` → `/config`, with two exceptions:
plex uses `/mnt/user/appdata/plexmediaserver`, and calibre additionally binds
`/mnt/user/Media/books` → `/config/Calibre Library` (note the space in the path).

| Container | Media binds |
|---|---|
| `plex` | `tv`→`/mnt/tv`, `movies`→`/mnt/movies`, `music-rb`, `music-reg`, `podcasts`, `appdata/transcode`→`/mnt/transcode`, plus `/etc/localtime:ro` |
| `sonarr` | `tv`→`/tv`, `downloads`→`/downloads` |
| `radarr` | `movies`→`/movies`, `downloads`→`/downloads` |
| `qbittorrent` | `downloads`→`/downloads` |
| `lazylibrarian` | `books`→`/books`, `downloads`→`/downloads` |
| `calibre` | `books`→`/config/Calibre Library` |
| `prowlarr` | none (indexer proxy only) |
| `PortainerCE` | `/var/run/docker.sock` (rw) |

appdata sizes: plex 20G, radarr 3.0G, lazylibrarian 205M, prowlarr 88M,
sonarr 383M, qbittorrent 16M, calibre 8.1M, gluetun 7.0M, portainer 920K.

### Special requirements

- `plex` — `/dev/dri:/dev/dri` passthrough for Intel QuickSync transcoding
  (matches the `intel-gpu-top` plugin), plus a `PLEX_CLAIM` token and a pinned
  `VERSION` env var.
- `gluetun` — `cap_add: NET_ADMIN`.
- `lazylibrarian` — `DOCKER_MODS=linuxserver/mods:universal-calibre`.
- `calibre` — `PASSWORD` + `CUSTOM_USER` for GUI auth (both are secrets).

## The VPN topology, as found

**The gluetun sidecar pattern is already in place.** `qbittorrent` runs
`network_mode: service:gluetun` and has no network namespace of its own;
`gluetun` sits on the `qbittorrent_default` bridge at `172.18.0.2` and publishes
qbittorrent's WebUI on host port **30024** and torrent traffic on **6881**
tcp+udp.

Facts ticket 06 will care about:

- **Provider is NordVPN**, WireGuard, pinned to `us8240.nordvpn.com`
  (Seattle, US). `VPN_PORT_FORWARDING=off` — NordVPN does not offer port
  forwarding, so **seeding is already crippled** and no configuration change
  fixes it. That is a provider question, not a topology one.
- **The *arr services cannot reach qbittorrent by container name.** sonarr and
  radarr are on the default `bridge` network (172.17.0.0/16); gluetun is on
  `qbittorrent_default` (172.18.0.0/16). Today the only path is the host:
  `192.168.1.195:30024`. Anything the repo defines has to either put them on a
  shared network or keep going via the host.
- **Two firewall env vars in the existing stack look like no-ops.**
  `FIREWALL_VPN_INPUT_ALLOW=192.168.1.0` and `FIREWALL_OUTBOUND_SUBNET=0.0.0.0/0`
  are set, while gluetun's actual variables (`FIREWALL_INPUT_PORTS`,
  `FIREWALL_OUTBOUND_SUBNETS`, plural) are empty in the container's environment.
  Worth confirming in 06 before the repo copies them forward.
- The qbittorrent WebUI on 30024 binds `0.0.0.0`, so it is LAN-reachable today
  with no auth in front of it beyond qbittorrent's own.

## The PUID/PGID problem

Three different uid sets are writing to the same media tree:

- `qbittorrent` writes downloads as **1001:1001** into `/mnt/user/Media/downloads`
- `sonarr`, `radarr`, `lazylibrarian` read that same directory as **99:100**
  (unraid's `nobody:users`) with `UMASK=022` — which denies group write
- `plex` reads the library as **1000:1000**

`UMASK=022` means files land group-read-only, so hardlinking or moving imports
out of `/downloads` across uids is fragile. This is pre-existing and unrelated to
GitOps, but git is about to encode these values permanently, so it gets decided
first — see [09](../issues/09-unify-uid-gid.md).

Timezones diverge too (`America/Vancouver`, `America/Los_Angeles`, `UTC`), though
the first two are the same offset.

## Stale artifacts

- Image `ghcr.io/bubuntux/nordvpn:get_private_key` (3 years old) — left over from
  generating the WireGuard key.
- Image `plexinc/pms-docker:latest` (10 months) — unused; the running plex is the
  linuxserver.io one.
- `/mnt/user/appdata/scratch` (4.0K) and `/mnt/user/appdata/transcode` (0) —
  transcode is plex's scratch dir, `scratch` is unattributed.

## Homepage does not exist

No `homepage` container, no `/mnt/user/appdata/homepage`, no homepage YAML
anywhere under appdata. The map assumed a migration; it is a **greenfield
deploy**. Good news for the proving case — there is no adoption risk in
[08](../issues/08-deploy-homepage.md) at all, only the reconcile loop itself.

## Secrets present on the box

Named here so [03](../issues/03-secrets-handling.md) knows the full set. Values
are redacted everywhere in this repo.

| Secret | Where it lives now |
|---|---|
| `WIREGUARD_PRIVATE_KEY` (NordVPN) | plaintext in Portainer stack 2's compose |
| `PLEX_CLAIM` | plaintext in Portainer stack 1's compose |
| calibre `PASSWORD` + `CUSTOM_USER` | plaintext in `my-calibre.xml` on `/boot` |
| sonarr / radarr / prowlarr / qbittorrent API keys | inside each service's appdata DB or `config.xml`; **not** in any env var, so they were not captured here and will need pulling from each UI when homepage widgets are wired |

Note the last row: the *arr API keys are not environment variables. They live in
`/config/config.xml` inside each appdata dir. Nothing needs to inject them into
the *arr containers — only *homepage* consumes them.

### Two leaks during capture

Both scrubbed from this repo, both disclosed to the agent's context:

1. **calibre GUI password** — stored as `<Config ... Mask="true">text</Config>`
   element text, which a `KEY=value` redactor walks straight past.
2. **NordVPN WireGuard private key** — stored as YAML `KEY: "value"` in the
   Portainer compose, which the same redactor also missed.

**Ruled not worth rotating** (2026-08-01): both are low-severity — a NordVPN
client key grants VPN egress but no access to the box, LAN or tailnet, and
calibre is LAN-only today. Both were already plaintext on the box beforehand, so
the marginal exposure is small. 03 will re-issue the WireGuard key anyway as a
side effect of picking a secrets mechanism. See the map's Secret severity note.

The lesson for any future probe: redact on *three* shapes — `KEY=value`,
`KEY: value`, and XML element text. Only the first was covered.
