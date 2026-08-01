# 09 — Unify PUID/PGID/UMASK, and decide what happens to files already written

Type: grilling
Status: open

## Question

Surfaced by [01 — Inventory the containers already running on the box](01-inventory-running-containers.md).
Three different uid sets are writing to one media tree:

| | uid:gid | writes | reads |
|---|---|---|---|
| `qbittorrent` | 1001:1001 | `/mnt/user/Media/downloads` | |
| `sonarr`, `radarr`, `lazylibrarian` | 99:100 (`nobody:users`) + `UMASK=022` | media library | `downloads` |
| `plex` | 1000:1000 | | media library |
| `calibre`, `prowlarr` | 99:100 | | |

`UMASK=022` denies group write, so files qbittorrent lays down as 1001:1001 are
read-only to the *arr that have to import them. This is pre-existing and nothing
to do with GitOps — but git is about to encode these values permanently across
eight services, so it is cheaper to settle now than to encode the mess and
migrate later.

Settle:

- **One uid:gid for everything, or deliberate exceptions?** unraid's convention
  is 99:100; two of the three Portainer-managed containers are on 1000:1000
  instead, and it is not clear that was a choice rather than a copied example.
- **What `UMASK`** — `022` as now, or `002` so group write survives, which is
  what makes cross-service imports work.
- **What happens to files already on disk.** This is the part with teeth: a
  `chown -R` across `/mnt/user/Media` touches the whole library (20G of plex
  appdata alone, plus the media itself), takes real time on the array, and is
  the one step here that can lose access to data if it goes wrong. Decide
  whether it is a big-bang chown, a per-share migration, or whether the ids are
  chosen to *avoid* a chown entirely.
- **Whether qbittorrent and the *arr should hardlink rather than copy** between
  `/downloads` and the library — this only works if they share a uid *and* the
  paths sit on one filesystem, so it constrains the answer above.

Not blocked: this needs only the inventory, which is done.
[07 — Decide the repo layout and per-service conventions](07-repo-layout-and-conventions.md)
will ask where the trio *lives* in the repo; this ticket decides what the values
*are* and how the box gets there.

**HITL** where it touches the box — per the map's Box access note, any chown or
verification runs as a hand-off checklist, not by the agent.
