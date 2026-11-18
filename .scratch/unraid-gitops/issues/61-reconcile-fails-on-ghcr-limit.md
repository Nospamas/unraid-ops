---
id: "61"
title: The nightly reconcile has failed every night since automerge
type: task
status: closed
description: >
  Sixteen straight nights, 11-02 to 11-17, each a `toomanyrequests` from GHCR's
  per-namespace limit on `linuxserver` — shared with the world, and exhausted at
  HH:00 when everyone's cron fires. The schedule moves to 3:37, and
  `just failures` reads the error an alert only links to.
touches:
  - komodo/procedures.toml
  - scripts/komodo.sh
  - justfile
  - stacks/gatus/conf/config.yaml
  - docs/conventions.md
  - CLAUDE.md
  - bootstrap/README.md
---

# 61 — The nightly reconcile has failed every night since automerge

Resolved: 2026-11-17
Blocked by: —

## Question

ntfy held two "Procedure reconcile failed" alerts and three VPN probe alerts.
What failed, and what fixes it?

## Answer

**Reconcile.** Every 3am run from 11-02 has failed at `Compose Pull` on a
linuxserver image — `download` five nights, then `bazarr` — with
`toomanyrequests: retry-after: <µs>, allowed: 44000/minute`. That figure is
GHCR's limit **per namespace**, not per client: lscr.io serves
`ghcr.io/linuxserver`, so every linuxserver user on earth shares it, and a cron
at `HH:00:00` lands in the minute they all fire. It started 11-02 because
[60] put linuxserver on automerge and the 3am run began pulling it at all
[49]. A failed Stack fails the Procedure, so the bumps behind it waited a night
each, and the same Stacks lost again.

`just reconcile` at 03:14 UTC pulled the same images cleanly and converged the
box. The schedule moves to `0 37 3 * * ?`. A retry inside the Procedure was not
taken: Komodo stages have none, and the retry-after is microseconds, so the
cause is the minute chosen rather than the attempt count.

**Reading the failure took a new recipe.** The alert links to the web UI; the
cause is two Updates deep. `just failures [days]` prints them with the nested
error, read-only, and is the first step of reviewing any Komodo alert.

**VPN.** The pinned `us13886` now exits from `187.15.91.67` rather than `.60`;
`vpn-tunnel` blipped and recovered, and qbittorrent followed the new address,
so its binding held. Both pin literals moved; no tracker hand-off
([06], as corrected 11-01).
