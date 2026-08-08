---
id: "47"
title: Add audiobookshelf
type: task
status: open
description: >
  Add audiobookshelf against a media share that holds 6.2G of podcasts and
  zero audiobooks — so it ships as a podcast server that is ready for
  audiobooks. The decision is which trees it binds, and whether it may write
  to them.
touches: []
---

# 47 — Add audiobookshelf

Blocked by: —
Claimed by: claude session, 2026-08-08

## Question

Picked in [45](45-pick-from-the-survey.md). `ghcr.io/advplyr/audiobookshelf` —
audiobooks and podcasts with progress sync and its own apps. Homepage ships an
`audiobookshelf` widget.

**Know what it is being pointed at before writing the binds.** [45] read the
share:

| tree | what is actually there |
|---|---|
| `${MEDIA}/podcasts` | 6.2G, one series (*Radiolab Complete*) |
| `${MEDIA}/books` | calibre's library — 514M, three epubs, `metadata.db`. **Zero `.m4b`, zero `.mp3`** |

So there are no audiobooks. This ships as a **podcast server ready for
audiobooks**, and the tile should not promise otherwise.

### The decisions

- **Which trees it binds.** `podcasts` is uncontested. `books` is *calibre's*
  library directory, `metadata.db` and all — [22](22-migrate-calibre.md) binds it
  as `/config/Calibre Library`, space and all. Pointing a second service at the
  same tree is the question: read-only, a separate `audiobooks` tree of its own,
  or not at all. **Two services writing one library is how a library gets
  corrupted**, so if `books` is bound, say why it is safe.
- **Whether it may write.** Audiobookshelf's podcast downloader writes into the
  podcast tree, and its scanner writes metadata beside media unless told not to.
  Decide before deploy, not after it has renamed something.
- **Where its own state goes.** `${APPDATA}/audiobookshelf` — it keeps metadata,
  users and progress in its own database, which is the appdata line and not
  git's.

### Then the routine

Per [docs/adding-a-service.md](../../../docs/adding-a-service.md), **new**
flavour. Known specifics:

- **Not a linuxserver image** — it reads no `PUID`/`PGID`. Set
  `user: "${PUID}:${PGID}"` *and* pre-create the bind target in `pre_deploy`, or
  docker creates it `root:root` and the container cannot write [29].
- No secret: its users live in its own database.
- `caddy.import: internal`, no host port, no `x-published`.
- Add a gatus probe, and take [36](36-add-bazarr.md)'s lesson — **a `/` that is
  200 only while auth is off is not a probe.** Find the endpoint that does not
  move.
- Add the Stack to `BatchDeployStackIfChanged` in
  [komodo/procedures.toml](../../../komodo/procedures.toml), then `just
  reconcile`.

## Hand-offs

To be recorded on resolution — expect at least the first-run admin account,
which only rb can create.
