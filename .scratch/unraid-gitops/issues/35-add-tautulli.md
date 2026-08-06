---
id: "35"
title: Add tautulli, and backfill plex's watch history
type: task
status: open
description: >
  Add tautulli wired to plex, with plex's existing watch history imported. The
  decision is how tautulli reads plex's database: no Stack has ever bound
  another Stack's appdata, and a `pre_deploy` copy from a path outside
  Periphery's binds is a no-op that reports success.
touches: []
---

# 35 — Add tautulli, and backfill plex's watch history

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
