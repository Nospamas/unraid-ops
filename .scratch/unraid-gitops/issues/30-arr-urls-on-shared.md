# 30 — Move the *arr's in-app URLs onto `shared`, and drop the host ports

Type: task
Status: closed
Assignee: Nospamas
Resolved: 2026-08-05
Blocked by: 24

## Question

Surfaced by [21](21-migrate-arr-stacks.md). The four *arr Stacks kept their host
ports — 8989, 7878, 9696, 5299 — and
[docs/conventions.md](../../../docs/conventions.md) says a host port exists only
when something must reach the container without going through Caddy. Something
does, and it is not a browser:

- prowlarr addresses sonarr and radarr as `http://192.168.1.195:8989` and
  `:7878` (its `Applications` rows)
- the indexers prowlarr *writes into* them point back at
  `http://192.168.1.195:9696` (`prowlarrUrl`)
- sonarr and radarr address qbittorrent as `192.168.1.195:30024`

Every one of those is a container-to-container path now that all of them are on
`shared`, and every one lives in **appdata that git does not own**. So this is
not a repo edit — it is app config changed through each UI or API, and then the
`ports:` blocks come out of four compose files.

Blocked by [24](24-migrate-download-stack.md): the qbittorrent leg is half the
work and gluetun holds that namespace, so doing this before the download Stack
migrates would only have to be redone.

The prize is small and real: four fewer LAN-open ports, and the `(internal)`
guard becoming the only way in rather than one of two.

**Do not do this piecemeal from a health-check warning.** A wrong URL in
prowlarr fails silently — search returns nothing and nothing logs an error.
Change the URLs first, confirm a search still returns results end to end, and
only then delete the ports.

## Unblocked by [24](24-migrate-download-stack.md), and one leg already walked

The download Stack is on `shared`, so `http://gluetun:30024` resolves for every
service here. Homepage has already moved — both its widget and its `container:`
entries — which leaves this ticket the four *arr and nothing else.

Two things 24 hands over:

- **`30024` is the download Stack's only host port now**; 6881 is gone. So this
  ticket ends with `ports:` disappearing from five compose files, not four.
- **qbittorrent's `AuthSubnetWhitelist` still carries `172.18.0.0/16`**, the dead
  `qbittorrent_default` subnet, kept only so 24's rollback would work. Drop it in
  the same pass that drops the port, leaving `172.20.0.0/16` and — decide —
  whether `192.168.1.0/24` is still earning its place once nothing on the LAN
  addresses qbittorrent directly.

## Resolution (2026-08-05)

Every in-app URL is a container name. `just lint` counts four Services with a
host port, down from eight.

**Two of this ticket's premises were wrong, and both were `x-host-port` prose
written by the ticket that opened the port:**

- **lazylibrarian's `5299` had a reader.** Prowlarr carries *three* Application
  rows, not two — LazyLibrarian among them. "No reader at all" was false.
- **`30024`'s second reader is gatus**, not an *arr: it probes
  `http://127.0.0.1:30024/api/v2/transfer/info`, the one check that catches
  [06](06-qbittorrent-vpn-topology.md)'s hazard. Deleting the port on that key's
  word would have taken the probe with it. **It narrows to `127.0.0.1` instead**
  — the prize was LAN reachability, not the publish.

Neither entry was wrong when written. **Check who dials the port, not what the
key claims** — handed to [31](31-plex-own-internet-exposure.md).

**`syncLevel: fullSync` did most of the work**: one `prowlarrUrl` edit plus an
`ApplicationIndexerSync` rewrote every downstream Torznab URL, lazylibrarian's
`config.ini` included. Only three edits were not prowlarr's — sonarr's and
radarr's download client `host`, and lazylibrarian's `qbittorrent_host`, which
needed a stop/edit/start because it rewrites `config.ini` on exit.

**Verified against a baseline taken first**: searches return the same counts (7
sonarr, 3 radarr), all tests 200. Lazylibrarian proved both legs unprompted in
its log — searched via prowlarr, pushed a torrent to qbittorrent at the new
address, removed it. The only `192.168.1.195` left in appdata is in its logs.

**`AuthSubnetWhitelist` is `172.20.0.0/16` alone.** `172.18.0.0/16` was 24's
rollback subnet — one line, held in `qBittorrent.conf.bak-30`, unlike Portainer
itself ([25](25-retire-portainer.md)). `192.168.1.0/24` admitted nothing: Caddy
is host-networked, so a LAN browser arrives from `172.20.0.1`. Gatus and
homepage's credential-free widget both re-verified after. **The auth fog is
narrowed, not closed.**

Not caused here: qbittorrent holds **10** torrents against 24's 23. `BT_backup`
agrees, and both *arr have `removeCompletedDownloads=true`.
