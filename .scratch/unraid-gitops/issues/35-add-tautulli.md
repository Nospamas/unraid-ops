---
id: "35"
title: Add tautulli, and backfill plex's watch history
type: task
status: closed
description: >
  Tautulli runs from git, probed on `/status` rather than `/`, with no plex
  appdata bind of any kind — **the backfill does not exist**. Tautulli cannot
  read plex's database, upstream closed that `wont-fix`, so the question's
  three-way choice was moot, and rb declined the one route left: a converter
  that invents the watch durations plex never recorded.
touches: [stacks/tautulli/, stacks/gatus/conf/config.yaml, komodo/procedures.toml]
---

# 35 — Add tautulli, and backfill plex's watch history

Resolved: 2026-08-06
Blocked by: —

## Question

Plex reports what is playing now and almost nothing about what has played. Add
tautulli, wired to plex, **with plex's existing history imported** — a graph that
starts empty is most of why this is worth doing at all.

Follow [adding-a-service.md](../../../docs/adding-a-service.md). The routine covers
the Stack; two things it does not cover are below.

### What the routine already answers

`${APPDATA}/tautulli:/config`, `shared`, `tautulli.rbrb.in`,
`caddy.import: internal`, port 8181, image pinned `version@digest`, no host port.
Tautulli reaches plex at **`http://plex:32400`** — a container name, per the
**Addressing** rule ([26](26-host-state-scope.md)) — and the plex token already
exists in the repo as `HOMEPAGE_VAR_PLEX_TOKEN` in
[stacks/homepage/secrets.sops.env](../../../stacks/homepage/secrets.sops.env).
Decide whether tautulli takes its own copy as a Stack secret or reads plex out of
its own setup wizard into appdata; the second is what
[CONTEXT.md](../../../CONTEXT.md) implies, since service settings are not
reconciled.

### The backfill — this is the decision

Tautulli can import plex's own viewing history out of
`com.plexapp.plugins.library.db`, under
`${APPDATA}/plexmediaserver/Library/Application Support/Plex Media Server/Plug-in Support/Databases/`.

**This is a new shape for this repo: every Stack so far has bound its own appdata
directory and nothing else.** Decide how the read happens, and say why:

- a **read-only bind** of plex's database directory into the tautulli Stack —
  simplest, but makes one Stack's compose file depend on another Stack's appdata
  layout, which nothing else here does
- a **copy taken in `pre_deploy`** into tautulli's own appdata — keeps the binds
  clean, but `pre_deploy` runs inside Periphery, which sees only what its binds
  allow ([29](29-alerting-on-failed-reconcile.md)); **a path outside them is a
  no-op that reports success**
- a **one-off manual copy over SSH**, with nothing about it in git — honest about
  being a one-time migration rather than a standing dependency

Also establish whether plex must be **stopped** for a consistent read (SQLite
with a live writer), and if so state that as a planned outage with a rollback,
per [CLAUDE.md](../../../CLAUDE.md).

### Do not forget

- **Add a gatus probe** to [stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml).
  The routine never tells you to — it appears only in that doc's Traps section —
  so a new service lands unmonitored by default. Consider fixing the doc; the map
  carries that as fog.
- **Add `tautulli` to the `BatchDeployStackIfChanged` pattern** in
  [komodo/procedures.toml](../../../komodo/procedures.toml) — the list is explicit,
  never `*`, and a Stack missing from it is never deployed. Then `just reconcile`,
  because the cron cannot apply a `procedures.toml` edit.
- **One Stack at a time.** Map 01 learned this the hard way in
  [21](21-migrate-arr-stacks.md); do not batch this with [36](36-add-bazarr.md).
- **A green reconcile is not a running service.** Check the workload.

### Out of scope

**Tautulli's notification agents.** Ruled out while charting:
[29](29-alerting-on-failed-reconcile.md)'s gatus already probes plex end to end,
so plex-is-up is answered, and playback pings would dilute the topic that carries
real failures.

## Hand-offs

Expect one — tautulli's first-run wizard wants a plex sign-in.

## Answer

**The Stack is routine. The backfill does not exist**, so the decision this
ticket was written for was never available to make.

### Tautulli cannot read plex's database

Not a permissions problem and not a bind problem. Tautulli has no importer for
`com.plexapp.plugins.library.db` at all — **Settings → Import & Backups** takes
a PlexWatch/Plexivity database or another Tautulli database, and nothing else.
Upstream closed the request `wont-fix`
([Tautulli#2181](https://github.com/Tautulli/Tautulli/issues/2181)), on the
grounds that plex's own record is too thin to build tautulli's history from.

So all three options in the question — the read-only bind, the `pre_deploy`
copy, the SSH copy — answered a question nobody was asking. **No Stack binds
another Stack's appdata, and this one did not become the first.** The
consistency question went with it: plex was never stopped, and needed no
snapshot, because nothing was ever going to read the file.

One stale premise worth correcting for whoever reads it next: a `pre_deploy`
copy would **not** have been a no-op. Periphery binds the whole of
`/mnt/user/appdata` since [29](29-alerting-on-failed-reconcile.md) — verified on
the box, `docker inspect komodo-periphery` — which
[conventions.md](../../../docs/conventions.md#pre_deploy) already says. The
warning applies to paths outside appdata.

### The backfill, decided by rb: none

What plex actually holds, measured through its own `Plex SQLite` against a
read-only handle on the live database:

| | |
|---|---|
| views | 559 — 374 episodes, 152 movies, the rest tracks and extras |
| span | 2025-11-16 → 2026-08-06 |
| accounts | 10 |

Nine months, not years. The only route to it is a third-party converter
([austinmh12/plex-to-tautulli](https://github.com/austinmh12/plex-to-tautulli),
ten commits) that reads the **plex API** rather than the database and emits a
synthetic tautulli database to upload — with invented watch durations, since
plex does not record them, and no device, IP or transcode data.

**rb chose no backfill.** Plex keeps its own 559 rows and stays the record of
what came before; tautulli logs from today. Nothing is lost, only unmerged — and
because the converter reads a live API rather than a file that ages, this is
exactly as available in a year as it was today. Seeding the dataset with
fabricated durations is not.

### The Stack

`v2.17.2-ls238`, `${APPDATA}/tautulli:/config`, `shared`, no host port,
`caddy.import: internal`, `tautulli.rbrb.in` → 8181, added to
`BatchDeployStackIfChanged` and deployed by `just reconcile`. Container up,
appdata `99:100`, and `http://plex:32400/identity` answers 200 from `shared` —
the container name, per [26](26-host-state-scope.md)'s Addressing rule.

**No secret.** The plex token is not copied out of homepage's
`secrets.sops.env`: tautulli's wizard writes its own into `config.ini`, which is
appdata, which is where [CONTEXT.md](../../../CONTEXT.md) puts service settings.
One more copy of that token in git would have been a second thing to rotate.

**The probe is on `/status`, not `/` — the only one in the file that is.**
Tautulli's root answers 303 to `/welcome` until the wizard is done, then 200 or
302 to `/auth/login` depending on whether a password is set. That is a status
that moves under a setting in appdata, which is not something to assert.
`/status` is its healthcheck endpoint: unauthenticated, `200` with
`{"result": "success"}` either side of both. Measured, then asserted.

First reconcile failed on `toomanyrequests` from lscr.io mid-pull — the
registry's own rate limiter, nothing to do with this repo. The retry was clean.

### What this leaves

The routine still never tells anyone to add a probe — this ticket did, and only
because it was written into the ticket. Graduated out of the map's fog as
[44](44-probe-step-in-the-routine.md).
