# What else runs alongside this stack

Asset of [40](../issues/40-survey-complementary-services.md). Surveyed
2026-08-07. **Recommends; installs nothing.**

> **Corrected the same day, in [45](../issues/45-pick-from-the-survey.md), by
> looking at the media share instead of reasoning about it.** Three claims below
> were wrong and are struck through where they appear: unpackerr was ruled out on
> a false premise, "no music here at all" was 550G wrong, and audiobookshelf's
> precondition has an answer. Reading the box first would have caught all three.

Running today: plex, sonarr, radarr, prowlarr, qbittorrent behind gluetun,
calibre, lazylibrarian, tautulli, bazarr, plus caddy/coredns/gatus/ntfy/homepage/
komodo/dockerproxy.

The bar was **a real gap**, not a nicer version of something running. Maintenance
was checked against the registry, not the README: every image below has a real
version tag, so `version@digest` per [12](../issues/12-image-update-strategy.md)
is available for all of them.

## Worth a ticket

### Cleanuparr — the download queue nobody watches

`ghcr.io/cleanuparr/cleanuparr:2.10.2`. Removes stalled, blocked and
malicious-content downloads from qbittorrent and the *arr queues, blocklists the
release and triggers a re-search. **The gap is real**: sonarr and radarr will
wait on a dead torrent indefinitely, and nothing on this box notices.

Needs sonarr/radarr/prowlarr API keys and qbittorrent's address — which is
`http://gluetun:30024`, since qbittorrent has no address of its own
([24](../issues/24-migrate-download-stack.md)). Web UI on 11011, so it fronts and
probes like everything else. No homepage widget; it would be a tile with a
`container:` and no data.

Supersedes **Decluttarr**, which is the tool most guides still name and is being
retired in its favour.

### Maintainerr — the library nobody prunes

`ghcr.io/maintainerr/maintainerr:3.13.0`. Rule-based cleanup of the plex library:
collect what matches a rule, show it as "leaving soon", delete it after a grace
period. Reads plex, the *arr and tautulli — **tautulli is what makes its rules
answerable**, since "watched by nobody in a year" is a tautulli question, and
[35](../issues/35-add-tautulli.md) only just made it askable.

Needs a plex token, *arr keys, tautulli's key, and delete rights over the media
share. That last one is the decision: it is a rule engine holding the delete
button on `/mnt/user/Media`, and its rules live in its own SQLite, not in git.
No homepage widget.

### Recyclarr — the quality profiles nobody curates

`recyclarr/recyclarr:8.7.1`. Syncs TRaSH-guides custom formats and quality
profiles into sonarr and radarr on a schedule. The gap is real — those profiles
are hand-set today and drift — but this one **argues with the repo's own line**:
[CONTEXT.md](../../../CONTEXT.md) says service settings are explicitly not
reconciled, and recyclarr's whole job is reconciling a subset of them from a
config file that would sit in git. That tension is the ticket, not an obstacle to
it.

Needs both API keys and a config directory bind — a **directory**, since a git
pull replaces a bound file. No web UI at all: no caddy label, no homepage widget,
and **no HTTP endpoint for gatus to probe** — see the routine gap below.

### Seerr — requests, and the decision it drags with it

`ghcr.io/seerr-team/seerr:v3.0.1`. The February 2026 merge of Overseerr (archived
2024) and Jellyseerr; supports plex natively, and homepage ships a `seerr`
widget. Port 5055, plex token, sonarr/radarr keys, appdata.

**Its whole point is other people asking for things**, which is a second Service
with an external route — exactly the trigger the open-questions register names
for authentication in front of the services, and the premise
[31](../issues/31-plex-own-internet-exposure.md) left standing. Kept `internal`
it is a nicer search box for rb alone, which probably fails the gap bar. So the
ticket is not "add seerr", it is "does anyone else request media" — and if yes,
it is published, and the auth question comes with it.

### Audiobookshelf — the format nothing here plays

`ghcr.io/advplyr/audiobookshelf`. Audiobooks and podcasts, with progress sync and
its own apps. Calibre stores ebooks and lazylibrarian acquires them; **nothing on
this box plays an audiobook.** Homepage widget: yes. Needs its own media bind and
appdata, no secret, no host port.

~~Precondition, not a decision: worth a ticket only if rb has audiobooks. An
empty library is a tile that says zero.~~ **Answered from the box in
[45](../issues/45-pick-from-the-survey.md): there are no audiobooks.**
`/mnt/user/Media/books` is calibre's library — 514M, three epubs, a
`metadata.db` — with zero `.m4b` and zero `.mp3` in it. What does exist is
`/mnt/user/Media/podcasts`, 6.2G of one series. So audiobookshelf lands as a
podcast server that is ready for audiobooks, which is a different service from
the one this entry described.

### Unpackerr — reinstated

~~Ruled out below on the grounds that nothing here arrives as split archives.~~
**That premise was wrong**: torrent releases arrive rar'd too, and
`/mnt/user/Media/downloads` holds a 40-part rar set that radarr could not import
— the extracted `.mkv` is sitting loose in the movies root, unrenamed, which is
what a hand extraction looks like. `ghcr.io/unpackerr/unpackerr:0.15.2`, already
running in home-ops at
`kubernetes/apps/media/unpackerr/app/helmrelease.yaml` — a working reference for
the *arr wiring. It has a web server (`UN_WEBSERVER_LISTEN_ADDR`), so unlike
recyclarr it probes and fronts normally, and homepage ships an `unpackerr`
widget.

## Conditional — a trigger, not a plan

- **Byparr** `ghcr.io/thephaseless/byparr:1.0.10` — drop-in FlareSolverr
  replacement (same API, same port) using an anti-detection browser. FlareSolverr
  itself has degraded through 2026 against Cloudflare's managed challenges.
  **Install nothing until a prowlarr indexer actually fails a challenge**; costs
  ~1GB of RAM for a headless browser when it does.
- **Kometa** `kometateam/kometa:v2.4.6` — collections, overlays and artwork for
  plex. Real, but cosmetic-adjacent, headless like recyclarr, and its config is a
  large YAML that reopens the same git-owns-settings argument.
- **Lidarr + Navidrome** — ~~there is no music here at all, so the gap is
  total~~ **wrong, and wrong in the direction that matters**: the box holds
  **550G of music** across `music-rb` (440G, 1025 loose files) and `music-reg`
  (110G, 1104 artist directories). It is unmanaged and unserved — nothing indexes
  it, nothing plays it, and the two trees are organised differently from each
  other. That makes Navidrome the stronger half of this pair and Lidarr the
  optional one, which reverses the entry. **Lidarr's metadata server has still
  been unreliable through 2026**, so acquisition is the shaky part while serving
  what already exists is not. Both have homepage widgets.

## Ruled out, and why

| candidate | why not |
|---|---|
| Uptime Kuma | gatus already does this [29] |
| Watchtower, What's Up Docker | Renovate plus digest pinning owns updates [12]; a container that mutates containers is the opposite of this repo |
| Dozzle, Portainer-alikes | Komodo, and [25](../issues/25-retire-portainer.md) retired Portainer on purpose |
| Notifiarr | ntfy is the alert path [29]; a second notifier splits the topic |
| Decluttarr | superseded by Cleanuparr |
| Overseerr, Jellyseerr | archived and merged respectively — new installs take Seerr |
| Readarr | archived June 2025 when its metadata backend went offline; the forks (Librarr, Bindery, Shelfmark) are alpha/beta. lazylibrarian already runs |
| ~~Unpackerr~~ | ~~nothing here arrives as split archives — no usenet client on the box~~ — **reinstated above**: rar'd torrents are the case this missed, and one is sitting in the download share right now |
| cross-seed, autobrr, qbit-manage | the download stack is leech-only [24]; there is no seeding to manage |
| Scrutiny | disk health is the Unraid GUI's job, and [26](../issues/26-host-state-scope.md) holds host state out of git |
| Tdarr, FileFlows, Unmanic | transcoding is a CPU commitment and rewrites the library in place; nothing says the library needs it |
| Wizarr | invites for external users — the auth question with none of Seerr's value unless Seerr lands first |
| Immich, Paperless-ngx, Karakeep, Mealie | real services, different domains. A new map, not this stack's neighbours |
| Kopia, Backrest, Duplicati | **not a new candidate** — this is the deferred *Appdata backup and box rebuild* question in [open-questions.md](../open-questions.md), and it stays there |

## One finding that is not a candidate

**The routine assumes a web UI.** [docs/adding-a-service.md](../../../docs/adding-a-service.md)
ends every service at a caddy label, a gatus probe and a homepage tile, and every
one of the sixteen probes in `stacks/gatus/conf/config.yaml` is HTTP. Recyclarr
and Kometa are scheduled jobs with no listener — no hostname, no probe endpoint,
no tile with anything on it. Adopting either one means deciding **how this repo
knows a headless Stack is alive**, and that decision arrives before the first one
of them does.
