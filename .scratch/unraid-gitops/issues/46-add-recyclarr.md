---
id: "46"
title: Add recyclarr
type: task
status: open
description: >
  Add recyclarr, which owns a named slice of sonarr's and radarr's settings
  from git — allowed, but it has to say which slice, or the next person to
  edit a quality profile in the UI loses it without warning. It is also the
  repo's first headless Stack: no caddy label, no tile, nothing to probe.
touches: []
---

# 46 — Add recyclarr

Blocked by: —

## Question

Picked in [45](45-pick-from-the-survey.md), surveyed in
[40](40-survey-complementary-services.md). `recyclarr/recyclarr:8.7.1` syncs
TRaSH-guides custom formats and quality profiles into sonarr and radarr on a
schedule, because those profiles are hand-set today and drift.

**Two decisions come before the routine**, and neither is a taste call.

### Say which settings it owns

This ticket was first written claiming recyclarr contradicts
[CONTEXT.md](../../../CONTEXT.md). **It does not, and the doc has been corrected**
— reconciled or in appdata is a per-service choice, the default is appdata, and
homepage was never an exception to a rule. So there is no permission to seek.

What is left is the real question and it is narrower: **which settings recyclarr
owns.** It writes custom formats, their scores and the quality profiles that
carry them; it does not touch indexers, root folders or download clients. Write
that boundary down where a person hunting for it will find it, because the
failure mode is silent — someone tunes a quality profile in sonarr's UI and the
next sync reverts it with no error anywhere.

Which also settles whether the `recyclarr.yml` is a `config_files` entry: it is
git-owned settings, so it is listed, or a push that edits it is invisible to the
loop.

### It is the first Stack with nothing to probe

The fog [40] surfaced is now this ticket's. Recyclarr is a scheduled job with no
listener: no `caddy` label, no hostname, no homepage tile with anything on it,
and **no HTTP endpoint** — where all sixteen probes in
[stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml) are HTTP.
[docs/adding-a-service.md](../../../docs/adding-a-service.md) ends every service
at those three things and has no answer for a Stack that has none of them.

Decide how this repo knows a headless Stack is alive, and write it into the
routine — it applies to Kometa and anything else scheduled, not just this one.
`caddy.import: internal` is never dropped to satisfy the lint; check what
`scripts/check-exposure.sh` actually requires of a Stack with no caddy label at
all before assuming it needs an exemption.

### Then the routine

Per [docs/adding-a-service.md](../../../docs/adding-a-service.md), **new** flavour.
Known specifics:

- Both API keys are secrets — `just secret recyclarr`, never `sops --encrypt`.
- Its config is a `recyclarr.yml`. **Bind the directory, never the file.**
- Sonarr and radarr are reached by container name on `shared`.
- Add the Stack to the `BatchDeployStackIfChanged` list in
  [komodo/procedures.toml](../../../komodo/procedures.toml) — explicit, never `*`
  — then `just reconcile`, not the cron.
- A green reconcile is not a running service. Check it actually synced something.

## Hand-offs

To be recorded on resolution.
