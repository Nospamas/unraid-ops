---
id: "57"
title: Reconcile once a day at 3am, not every 15 minutes
type: task
status: closed
description: >
  The poll drops from every 15 minutes to 3am daily, because `just reconcile` is
  what anyone actually uses when they want a change now and the timer was only
  ever the backstop. The edit that prompted this had `3` in the seconds slot —
  hourly at HH:00:03, not 3am — which is the trap the six-field format sets.
touches:
  - komodo/procedures.toml
  - CLAUDE.md
  - docs/conventions.md
  - bootstrap/README.md
  - .scratch/unraid-gitops/open-questions.md
---

# 57 — Reconcile once a day at 3am, not every 15 minutes

Resolved: 2026-08-22
Blocked by: —

## Question

rb set the cron to daily-at-3am, on the grounds that anything needing to land
sooner gets `just reconcile`. The value written was `3 0 * * * ?`.

## Answer

### The written value was not 3am

Komodo's `schedule_format = "Cron"` is six fields, **seconds first**, so the hour
is the third slot, not the first. `3 0 * * * ?` is *second 3 of minute 0 of every
hour* — hourly at `HH:00:03`. Daily at 3am is `0 0 3 * * ?`.

Nothing catches this: the old `0 */15 * * * ?` and the intended `0 0 3 * * ?`
are both valid, and a schedule that fires 24× more often than intended looks
exactly like one that works. The comment above the line now names the slot
rather than just the field count.

### Daily is the right cadence, and the 15 minutes was never load-bearing

The timer is the backstop, not the path. Every recipe that changes the box runs
`just reconcile` itself, and [27](27-recipe-safety-convention.md) already noted
the cron performs the identical Procedure whether anyone types it or not — so
shortening the window only narrowed the gap for a push made by someone who then
walked away.

Two things get slower and neither is load-bearing:

- **A push nobody follows with `just reconcile` takes up to 24h to land.** That
  is now the documented expectation rather than a surprise.
- **A `procedures.toml` edit that lands without `just reconcile` fails once a
  day rather than every 15 minutes** [16]. Fewer alerts for the same fault, and
  the fix is unchanged.

`KOMODO_RESOURCE_POLL_INTERVAL: 5-min` in
[bootstrap/compose.yaml](../../../bootstrap/compose.yaml) is **not** this and did
not change — that is Core noticing the ResourceSync's files, which reports
pending changes and applies nothing [11]. Deploying is the Procedure's second
stage, and only the Procedure's schedule governs it.

### Where the cadence was written down

Four standing docs stated 15 minutes as a live fact and now state the new one:
[CLAUDE.md](../../../CLAUDE.md), two places in
[docs/conventions.md](../../../docs/conventions.md),
[bootstrap/README.md](../../../bootstrap/README.md), and the
`Reconciling on push rather than on a timer` entry in
[open-questions.md](../open-questions.md), whose "15 minutes is the answer"
was the reason the question was not sharp.

Left alone deliberately: [komodo/alerters.toml](../../../komodo/alerters.toml)'s
header, `map-01-foundation.md` and [27], which describe what happened during
[16] at the cadence of the day. Those are history and rewriting them would make
the record wrong.
