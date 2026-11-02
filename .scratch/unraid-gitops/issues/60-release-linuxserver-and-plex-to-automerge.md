---
id: "60"
title: Release linuxserver and plex to automerge
type: task
status: closed
description: >
  The backlog gate from 49 held plex's bumps on the dashboard from August, and
  nothing surfaced it. Gate deleted; plex released from human merge. caddy and
  majors stay human; lazylibrarian stays off.
touches:
  - .renovaterc.json5
  - docs/conventions.md
---

# 60 — Release linuxserver and plex to automerge

Resolved: 2026-11-01
Blocked by: —

## Question

Can the box take linuxserver and plex bumps without a human?

## Resolution

**Yes.** The human wants the box as hands-off as possible.

[49]'s approval rule is deleted. It parked eight updates, and its pending list
produces no PR, so "merged everything" read as true while plex sat 12 builds
behind on the internet. Plex2Shell (CVE-2026-96652, 96654, 96655, 96656) was
exploited from October; `1.43.3.10861` was only safe by the luck of a single
August bump.

**plex is released.** On an internet-published Service, staleness is the larger
risk. The reason it was held still stands and is accepted: gatus proves plex
answers, not that a client can play or the B580 can transcode, so a bad bump is
found by someone watching something. A schema migration is forward-only; Plex's
own dated database backups are the rollback.

**Unchanged:**

- **caddy** — it fronts every hostname on 80/443, and its in-place digest
  rebuilds would not automerge regardless.
- **Majors** — [59] is why: unpackerr 1.x needed Stack changes the bump did not
  carry. calibre v9 arrives as a PR.
- **lazylibrarian** — off, by hand; no version to order by [49].
- **`bootstrap/`** — nothing reconciles it.

linuxserver rebuilds roughly weekly, so these Stacks now recreate most weekends,
at the 3am reconcile. qbittorrent alone does not touch gluetun, so this does not
move the VPN exit.

## What this leaves

- The first run lands the backlog at once, across seven Stacks.
- calibre v9 needs a human.
