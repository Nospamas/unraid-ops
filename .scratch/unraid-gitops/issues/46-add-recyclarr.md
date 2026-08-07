---
id: "46"
title: Add recyclarr
type: task
status: open
description: >
  Add recyclarr, whose job is reconciling a slice of the service settings
  CONTEXT.md says are never reconciled — so the ticket settles that line
  before it writes the Stack. It is also the repo's first headless Stack:
  no caddy label, no tile, and nothing for gatus to probe.
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

### It contradicts the line about service settings

[CONTEXT.md](../../../CONTEXT.md) says service settings — sonarr's indexers,
quality profiles, root folders — are explicitly not reconciled, and that a change
to one is not a `git push`. Recyclarr's entire product is reconciling a subset of
exactly those, from a config file that would live in git.

Settle it as a **rule with a citation**, in
[docs/conventions.md](../../../docs/conventions.md), not as a shrug in a compose
comment. The obvious shape is that the boundary was never appdata-versus-git but
*who owns each setting* — and recyclarr claims a named, bounded set. Say which
set, so the next reader knows whether editing a quality profile in sonarr's UI
will survive.

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
