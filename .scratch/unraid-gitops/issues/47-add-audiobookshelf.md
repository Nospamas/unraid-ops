---
id: "47"
title: Add audiobookshelf
type: task
status: closed
description: >
  audiobookshelf runs from git as a podcast server ready for audiobooks —
  read-write on podcasts, a new empty audiobooks tree of its own, and calibre's
  library untouched. It also found a hole in the routine: pre_deploy cannot
  prepare a media path, so the bind refuses to create one instead.
touches:
  - stacks/audiobookshelf/compose.yaml
  - stacks/audiobookshelf/komodo.toml
  - stacks/gatus/conf/config.yaml
  - stacks/homepage/config/services.yaml
  - komodo/procedures.toml
  - docs/adding-a-service.md
---

# 47 — Add audiobookshelf

Resolved: 2026-08-08
Blocked by: —

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

## Answer

`ghcr.io/advplyr/audiobookshelf:2.36.0` runs from git, probed on `/ping`, tiled
on homepage. **The three decisions, and the one the routine got wrong.**

### Its own tree, not calibre's

rb chose a new empty `${MEDIA}/audiobooks` over binding `books`. calibre keeps
sole ownership of its library and `metadata.db` [22], and the three epubs stay
calibre's to serve — audiobookshelf never sees them. The tile says *podcasts —
and audiobooks, once there are any*, which is the honest promise [45].

`podcasts` is bound **read-write**: subscribing to a feed and downloading its
episodes is most of what audiobookshelf does for podcasts, and read-only would
have shipped a player for 6.2G that never grows. The tree is `1001:100` mode
`775`, so gid 100 gets group write and 99:100 writes into it fine —
`touch` verified inside the container, not assumed.

State is two paths and not one: `CONFIG_PATH=/config` holds the sqlite database,
users and progress, `METADATA_PATH=/metadata` holds covers, cache, backups and
the upload temp dir. Both appdata's.

### `pre_deploy` cannot prepare a media path, and the routine said it could

The trap in [adding-a-service.md](../../../docs/adding-a-service.md) says a
non-linuxserver image needs `user:` *and* a `mkdir`/`chown` in `pre_deploy` — and
that is true only for appdata. **Periphery binds `/mnt/user/appdata` and not
`/mnt/user/Media`** [29], so a `mkdir` under `${MEDIA}` would have succeeded
inside Periphery, changed nothing on the host, and left docker to create the real
target `root:root`. That is 29's failure re-run with a different path, and the
routine would have walked the next person straight into it. The trap now says so.

The tree was created by hand instead — one `mkdir`, `chown 99:100`, `chmod 775`.
That leaves a gap git cannot close, so both media binds use compose's long
syntax for **`create_host_path: false`**: a missing tree is now a **failed
deploy the alerter reports**, rather than an empty `root:root` directory that
looks exactly like the empty correct one. Whether every media bind in the repo
should say that is [54](54-media-binds-refuse-to-create.md).

### `/` is a 200 and proves nothing

All three of `/`, `/ping` and `/healthcheck` answer 200 — measured, not assumed.
`/` is the Nuxt shell and renders the first-boot wizard and a logged-out login
form alike, so it is [36]'s trap exactly. `/ping` is registered in `Server.js`
**above** the static handler and **outside** the `/api` auth middleware, checked
in the source rather than inferred from the docs, and it answers
`{"success":true}` — a body worth asserting, which is what makes it better than
`/healthcheck`'s bare 200 sitting beside it.

Renovate needs no rule: the tag is plain semver, so the default `docker`
versioning orders it. That is the first non-linuxserver image added since [49].

### Verified

`Up`, not merely reconciled: the container is running, `/ping` is green in gatus
with both conditions passing, the tile renders in **Watch & Read**, and the
container writes to both media trees as 99:100.

## Hand-offs

The admin account, and the API key that only exists once it does — the key is on
[50](50-homepage-secrets-and-verify.md)'s list rather than here, because prose
does not block a close and an open issue does.
