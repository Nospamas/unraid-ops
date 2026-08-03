# 09 — Unify PUID/PGID/UMASK, and decide what happens to files already written

Type: grilling
Status: closed
Assignee: Nospamas
Resolved: 2026-08-01

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

## Note from [07](07-repo-layout-and-conventions.md)

07 has answered the *where*: `PUID`, `PGID`, `UMASK` and `TZ` live once in
**`common.env`** at the repo root, reaching every Stack through
`additional_env_files`. So this ticket writes four values into one file, not
eight compose files — which lowers the cost of changing them later, but not the
cost of the `chown` that is the part with teeth.

## Resolution

**The values, in [common.env](../../../common.env):** `PUID=99`, `PGID=100`,
`UMASK=002`, `TZ=America/Vancouver`, plus `APPDATA=/mnt/user/appdata` and
`MEDIA=/mnt/user/Media`.

**99:100 everywhere, no exceptions.** It is Unraid's own `nobody:users`, so it
is what the *rest of the box* already writes as — SMB shares, the file manager,
Docker Safe New Permissions — not merely what most containers happen to use.
Five of the eight services already carry it. Plex was offered an exception,
since it only ever reads the library and owns its own appdata, and the exception
would have skipped a 20G chown; it was declined on purpose. A permanent "except
plex" footnote in a repo whose whole point is uniform definitions is worth more
than one slow chown.

**UMASK=002** (664 files, 775 dirs). With every container on uid 99, owner-write
already covers every container-to-container handoff, so this changes nothing
between the eight services. It is there for everything that is *not* a
container: SMB writes, the Unraid file manager, and any future service that ends
up on a different id. `022` — today's value on five services — would work fine
right up until that happens, which is precisely how the current mess started.

**TZ=America/Vancouver.** Vancouver and Los_Angeles are the same offset and the
same DST rules, so nothing shifts; naming the zone actually lived in is what
stays correct if they ever diverge. qbittorrent's `UTC` was the only real change.

### The binds do not move, and hardlinks are out of scope

The grill went a long way down the opposite path before the evidence turned it
around, and the reasoning is worth keeping because it will look like an obvious
oversight otherwise.

The plan reached was TRaSH-style: one `${MEDIA}` → `/media` bind on every
service, unlocking hardlinked imports. Hardlinks are impossible today for a
reason that has nothing to do with uids — sonarr binds `Media/tv` → `/tv` and
`Media/downloads` → `/downloads` as *two separate bind mounts*, and `link()`
across mounts returns `EXDEV` even when both resolve to one filesystem. So
imports have always been copy-then-delete.

Then the array layout arrived: **six data disks** (12/12/8/8/12/12 TB), **39.1 TB
used**, each its own XFS, presented as one tree by shfs. A hardlink cannot cross
filesystems. No disk can hold a 39 TB library, so a download and its destination
share a disk only by chance — roughly **1 in 6**. shfs *does* support hardlinks
(the *Tunable (support Hard Links)* setting) and will create the link on the
source file's disk if the share's split level lets it materialise the
destination folder there — but that scatters a single show across disks, and
whether the split level even permits it was never captured. A **1 TB btrfs cache
pool** adds a second hazard: if the Media share is cache-enabled, the Mover
relocates downloads to the array later and does not preserve hardlinks.

Set against that, the cost was stored-path surgery in five services:

| service | what a re-path costs |
|---|---|
| sonarr, radarr | `sqlite3` on `RootFolders.Path` and `Series.Path`/`Movies.Path` |
| lazylibrarian | `config.ini` plus its DB |
| qbittorrent | bencode-aware rewrite of every `.fastresume`, plus `qBittorrent.conf` and `categories.json`; botched, a full re-check |
| plex | `Plex SQLite` (**not** stock `sqlite3` — custom collations) on `section_locations.root_path` and `media_parts.file` |
| calibre | nearly free — Switch Library to the new path, `metadata.db` lives inside the library dir |

Plex and calibre never link and never move files, so they were paying the
highest price in the table for no capability at all. The *arr and qbittorrent
were paying a real price for a benefit that is a coin flip.

So: **media binds stay exactly as found, per category.** Nothing in any service's
database is touched by this ticket, in any service. Single-mount and hardlinks
are **out of scope for this map** — not fog, because the frontier does not lead
there: `git push` reconciling the box does not require them. If the share layout
is ever restructured to make hardlinks viable, that is a fresh effort.

Recorded in [docs/conventions.md](../../../docs/conventions.md) under *Media
paths*, with an explicit "do not tidy these into a single mount" so the next
reader does not rediscover the idea and think it was never considered.

### How the box gets there

**One big-bang chown window**, everything stopped:
`chown -R 99:100` over `/mnt/user/Media` and the three divergent appdata dirs
(`plexmediaserver`, `gluetun`, `qbittorrent`), then `chmod` to 775/664 so the
tree matches `UMASK=002`. It runs under `nohup` with a log, because the Unraid
Web UI terminal closing must not kill it. Raised as
[20 — Chown the tree to 99:100](20-chown-to-99-100.md).

Per-service chowns were declined: `Media/downloads` is read and written by four
services, so it cannot be cleanly split, and the tree would sit in mixed
ownership for the whole migration. Unraid's built-in Docker Safe New Permissions
was declined too — it deliberately skips appdata, so the three divergent appdata
dirs would need a manual chown regardless, and it writes 777/666 rather than the
775/664 that `UMASK=002` produces.

**Sequencing.** The chown is its own window and depends on nothing — not Komodo,
not the repo layout — so it can run at any point before the first of plex,
gluetun or qbittorrent is adopted. Because no path changes, **adoption order is
unconstrained**: each service can adopt independently, and the import chain does
not have to move as a unit. (An earlier draft of this resolution had the import
chain atomic; that constraint existed only because of the `/media` move and died
with it.)

**New risk this creates, worth stating plainly.** Plex drops from uid 1000 to 99,
and `/dev/dri` access depends on the container user's supplementary groups. If
hardware transcoding stops after plex is adopted, that is a group problem to
solve, not grounds to give plex its uid back — the exception was already
declined. Noted in
[docs/adding-a-service.md](../../../docs/adding-a-service.md) as a check to run
after plex's first deploy.

### What this ticket did not settle

- Whether the Media share's split level, cache setting and hardlink tunable
  would permit hardlinks. Deliberately unanswered: the decision no longer turns
  on it.
- The four *arr download clients still need repointing at `gluetun:30024` per
  [06](06-qbittorrent-vpn-topology.md). That is a hand edit in four UIs, it
  lives in appdata, and it is untouched by anything here.
