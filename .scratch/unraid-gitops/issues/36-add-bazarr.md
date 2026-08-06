---
id: "36"
title: Add bazarr
type: task
status: closed
description: >
  Bazarr runs from git, media binds mirroring the *arr's, and ships inert as
  intended. The routine held: its one decision was the probe endpoint, and
  `/` failed 35's test — it is a 200 only while bazarr's UI auth is off.
  `/api/system/ping` is the API's one keyless route and does not move.
touches: [stacks/bazarr/, stacks/gatus/conf/config.yaml, komodo/procedures.toml]
---

# 36 — Add bazarr

Resolved: 2026-08-06
Blocked by: —

## Question

Subtitles for sonarr and radarr. This is the routine in
[adding-a-service.md](../../../docs/adding-a-service.md) with no decision in it —
if a step needs one, the conventions are wrong and it goes against
[conventions.md](../../../docs/conventions.md) rather than being decided here.

### The one thing to get right

**Bazarr's media binds mirror sonarr's and radarr's exactly**, so bazarr sees
each file at the path the *arr report and no path mapping is needed:

```yaml
    volumes:
      - ${APPDATA}/bazarr:/config
      - ${MEDIA}/tv:/tv          # matches stacks/sonarr/compose.yaml
      - ${MEDIA}/movies:/movies  # matches stacks/radarr/compose.yaml
```

Otherwise: linuxserver image pinned `version@digest`, `shared`,
`bazarr.rbrb.in`, `caddy.import: internal`, port 6767, no host port. Bazarr
addresses the *arr as `http://sonarr:8989` and `http://radarr:7878` — container
names, per the **Addressing** rule ([26](26-host-state-scope.md)).

### No secret

Provider accounts are **rb's**, created and configured by him in bazarr's own UI
after this deploys. Nothing encrypted, no seventh secret, no provider decision on
this ticket. Bazarr ships inert and that is correct.

Its language profiles, scoring and provider list live in appdata and are **not
reconciled** — [CONTEXT.md](../../../CONTEXT.md)'s line, homepage being the sole
exception. The map carries as fog whether that should hold once there is tuning
worth losing.

### Do not forget

- **Add a gatus probe** to [stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml).
  The routine never tells you to — it appears only in that doc's Traps section.
  Bazarr with no provider configured may not answer 200; the condition is the
  service's **actual** unauthenticated status.
- **Add `bazarr` to the `BatchDeployStackIfChanged` pattern** in
  [komodo/procedures.toml](../../../komodo/procedures.toml), then `just reconcile` —
  the cron cannot apply that edit.
- **One Stack at a time** — do not batch with [35](35-add-tautulli.md).
- **A green reconcile is not a running service.** Check the workload.

## Hand-offs

- **rb** signs up for a subtitle provider (OpenSubtitles.com or similar) and
  configures providers and language profiles in bazarr's UI. Until he does,
  bazarr runs and downloads nothing.
- **rb** also connects bazarr to the *arr — the question left this implicit
  under "ships inert", and it is the larger half of the hand-off. Settings →
  Sonarr and Settings → Radarr, address `sonarr` / `radarr`, ports 8989 / 7878,
  no base URL, each *arr's API key from its own Settings → General. **Leave the
  path mappings empty**: that is what the media binds below bought.

## Answer

**The routine held.** Nothing in
[adding-a-service.md](../../../docs/adding-a-service.md) needed a decision, and
nothing went against [conventions.md](../../../docs/conventions.md). `v1.6.0-ls357`,
`${APPDATA}/bazarr:/config`, `shared`, no host port, `caddy.import: internal`,
`bazarr.rbrb.in` → 6767, added to `BatchDeployStackIfChanged` and deployed by
`just reconcile`. Container up, appdata `99:100`, `/tv` and `/movies` both list
the library from inside the container.

### The one decision: which endpoint the probe asserts

`/` answers **200** unauthenticated today, and asserting it would have repeated
the mistake [35](35-add-tautulli.md) caught one ticket earlier. Bazarr has its
own UI authentication — Settings → General, form or basic — and turning it on
moves the root. That setting lives in appdata, so it is not something git can
see change.

Three paths *look* like health endpoints and are not: `/health`, `/ping` and
`/system/status` each answer **200 with bazarr's HTML shell**, because they fall
through to the SPA catch-all. A probe on any of them asserts that a static file
is being served, not that bazarr works — the exact failure the whole file exists
to catch.

`/api/system/ping` is the API's one route that takes no key — **200** with
`{"status": "OK"}`, while `/api/system/status` beside it answers 401 — so it is
stable either side of rb's auth choice. Measured against the running box, then
asserted, and the probe is green in gatus.

### The media binds

`${MEDIA}/tv:/tv` and `${MEDIA}/movies:/movies`, matching
[sonarr](../../../stacks/sonarr/compose.yaml) and
[radarr](../../../stacks/radarr/compose.yaml) exactly, so no path mapping is
needed in bazarr's own settings. They are **not** a copy of the *arr's volume
list: `${MEDIA}/downloads` is deliberately absent, because bazarr works the
library rather than the grab.

### No secret, as predicted

Nothing encrypted, no seventh secret. Bazarr's settings landed as
`config/config.yaml` beside `db/bazarr.db` in appdata — the same text-plus-SQLite
split tautulli showed, which is the map's open fog about whether git should own
either.
