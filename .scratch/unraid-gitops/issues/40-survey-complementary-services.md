---
id: "40"
title: Survey what else commonly runs alongside this stack
type: research
status: closed
description: >
  Five candidates clear the gap bar — cleanuparr, maintainerr, recyclarr,
  seerr and audiobookshelf — and each carries a decision rather than an
  install: seerr drags the auth question forward, maintainerr wants delete
  rights on the media share, recyclarr reconciles the service settings this
  repo says it does not. The picking is rb's, in 45.
touches: [.scratch/unraid-gitops/assets/40-complementary-services.md]
---

# 40 — Survey what else commonly runs alongside this stack

Resolved: 2026-08-07
Blocked by: —
Asset: [assets/40-complementary-services.md](../assets/40-complementary-services.md)

## Question

Before the dashboard is reworked, settle what is *meant* to be on it. This box
runs plex, sonarr, radarr, prowlarr, prowlarr's indexers, qbittorrent behind
gluetun, calibre, lazylibrarian, and — after [35](35-add-tautulli.md) and
[36](36-add-bazarr.md) — tautulli and bazarr. Find the gaps worth filling.

Survey what people running this shape of stack commonly add, and for each
candidate record:

- **what it does that nothing here already does** — the bar is a real gap, not a
  nicer version of something running
- whether it is maintained, and what its image looks like (a pinnable
  `version@digest`, per [12](12-image-update-strategy.md) — **nothing is built on
  the box**)
- what it would need from this box: a media bind, a *arr API key, a host port, a
  secret, a device
- whether homepage ships a widget for it — relevant because
  [39](39-rework-homepage-dashboard.md) is next

Obvious ground to cover: request/discovery front-ends, a subtitle or metadata
tool bazarr does not already cover, music and audiobook management, download
client alternatives, dashboards and stats beyond tautulli, and the maintenance
utilities (orphan cleanup, library repair) that the *arr do not do themselves.
That list is a starting point, not a scope.

**This ticket recommends; it does not install.** Anything worth having becomes
its own ticket, which is also what makes it appear on the dashboard. Write the
findings to `../assets/40-complementary-services.md` and link it here.

Two standing constraints that rule candidates out cheaply, and are worth
applying while reading rather than after:

- **Nothing faces the internet without `x-published`**, and the trigger for
  adding authentication in front of the services is a *second* service with an
  external route ([31](31-plex-own-internet-exposure.md)). A candidate whose
  whole point is inviting outside users drags that decision forward with it — say
  so rather than quietly proposing it.
- **Every new Stack is one more thing Renovate tracks and gatus probes.** Cheap,
  but not free.

## Answer

Findings in
[assets/40-complementary-services.md](../assets/40-complementary-services.md) —
per candidate, the gap, the image, what it wants from the box, and the widget.
**Nothing was installed, and nothing was picked**: the picking is
[45](45-pick-from-the-survey.md).

Five clear the bar. What the survey did not expect is that **not one of them is a
free win** — each arrives holding a decision this repo has already made once:

- **Cleanuparr** — stalled and blocked downloads that the *arr will wait on
  forever. The cleanest of the five: an API key per *arr, qbittorrent reached at
  `gluetun:30024` because it has no address of its own [24], a normal web UI to
  front and probe. Supersedes **Decluttarr**, which most guides still name and
  which is being retired in its favour.
- **Maintainerr** — nothing prunes the plex library, and
  [35](35-add-tautulli.md) is what made "watched by nobody in a year" an
  answerable question in the first place. The decision is that it is a rule
  engine holding the delete button on `/mnt/user/Media`, with its rules in its
  own SQLite rather than git.
- **Recyclarr** — quality profiles drift because they are hand-set. It
  **contradicts [CONTEXT.md](../../../CONTEXT.md)'s own line** that service
  settings are not reconciled: reconciling a subset of them from a git-owned
  config is the entire product. That argument is the ticket.
- **Seerr** — the February 2026 merge of Overseerr (archived 2024) and
  Jellyseerr, so both names this ticket would have reached for are dead ends.
  Homepage ships the widget. But its point is *other people asking*, which is a
  second published Service — the exact trigger the open-questions register names
  for authentication in front of the services [31]. Kept internal it is a search
  box for rb alone and fails the gap bar. So the question is about rb's
  household, not about the box.
- **Audiobookshelf** — nothing here plays an audiobook; calibre stores and
  lazylibrarian acquires. No secret, no port conflict, its own media bind.
  Conditional on rb having audiobooks at all.

Conditional, with a trigger rather than a plan: **Byparr** only when a prowlarr
indexer actually fails a Cloudflare challenge (FlareSolverr has degraded through
2026 and Byparr is the drop-in), **Kometa** if curated plex collections are
wanted, **Lidarr + Navidrome** only if rb wants music — the gap is total, but
Lidarr's metadata server has been unreliable all year.

Fourteen candidates were ruled out; the asset carries the table. Three of those
rulings matter beyond this ticket: **Readarr is archived** (June 2025, metadata
backend offline) and its forks are alpha, so lazylibrarian is not a stopgap but
the live answer; **cross-seed, autobrr and qbit-manage all assume seeding**,
which a leech-only stack [24] does not do; and **the backup tools are not
candidates** — that is the deferred *Appdata backup and box rebuild* question in
[open-questions.md](../open-questions.md) and it stays there.

### The finding that is not a candidate

**The routine assumes a web UI.**
[docs/adding-a-service.md](../../../docs/adding-a-service.md) ends every service
at a caddy label, a gatus probe and a homepage tile, and all sixteen probes in
[stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml) are HTTP.
Recyclarr and Kometa are scheduled jobs with no listener — no hostname, nothing
to probe, nothing for a tile to show. Adopting either means first deciding how
this repo knows a headless Stack is alive. Carried as fog on the map, triggered
by picking one.

## Hand-offs

None — this is reading, and the picking is [45](45-pick-from-the-survey.md).
