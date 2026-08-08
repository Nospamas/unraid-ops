---
id: "50"
title: Land homepage's four secrets and verify the reworked page
type: task
status: open
description: >
  Four values only rb can supply — tautulli's and bazarr's API keys, and the
  latitude/longitude the weather widget reads from sops. A ticket rather than a
  hand-off note because 38 wrote exactly this requirement as prose and closed
  anyway, leaving two widgets erroring for a month.
touches: [stacks/homepage/secrets.sops.env, stacks/homepage/config/widgets.yaml]
---

# 50 — Land homepage's four secrets and verify the reworked page

Blocked by: 39

## Question

Nothing to decide. [39](39-rework-homepage-dashboard.md) settled every choice and
wrote the config; four values remain that only rb holds, and the page is not
finished until they are in and the result has been looked at.

**This is a ticket and not a line of prose on 39 for one reason.**
[38](38-homepage-tile-gaps.md) has a **Do not forget** section that says new
widgets need their API keys in `secrets.sops.env`. It closed without them, and
the tautulli and bazarr widgets have been erroring on the live page ever since —
found by reading the file during 39, not by anything failing. Prose does not
block a close; an open issue does.

### The four values

| var | where it comes from |
|---|---|
| `HOMEPAGE_VAR_TAUTULLI_KEY` | tautulli → Settings → Web Interface → API key |
| `HOMEPAGE_VAR_BAZARR_KEY` | bazarr → Settings → General → API key |
| `HOMEPAGE_VAR_LAT` | rb's coordinates, to ~4 decimal places |
| `HOMEPAGE_VAR_LON` | as above |

`just secret homepage`, **never `sops --encrypt`** — outside a Stack directory it
finds no creation rule. The age key is at `age.key`, restored from KeePassXC.

The coordinates are secrets rather than settings because **the repo is public**
[39]. `common.env` already publishes the metro through `TZ`; these would publish
the house.

### Then verify, because a green reconcile is not a running service

`compose.yaml` gained two read-only binds, so this is a **recreate**, not a
restart — `config_files` covers the config half but the compose change is what
Komodo diffs. Check the workload, not the update log.

- The header reads **resources / search / weather / clock**, in that order.
- The resources block shows **five** readouts — cpu, memory, uptime, and two
  disks. The array is 59T at ~62%, the cache pool 932G at ~10%. **If the disk
  figure looks like a small full-ish volume, the binds did not take** — that is
  the container overlay, the exact bug 39 fixed.
- The tautulli and bazarr tiles show data rather than an error.
- Weather renders. Until the coordinates land it will not, and that is expected
  rather than a second bug.

### While looking at it

39 left the theme unchanged and **deliberately unjudged**. To compare, set
`color: zinc` in `settings.yaml` and push; the reconcile picks it up. Record the
answer on this ticket so the theme stops being the one thing on the page nobody
ever chose.

## Hand-offs

The whole ticket. Every step needs rb.
