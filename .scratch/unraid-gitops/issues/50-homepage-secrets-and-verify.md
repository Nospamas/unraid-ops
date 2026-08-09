---
id: "50"
title: Land homepage's five secrets and verify the reworked page
type: task
status: open
description: >
  Five values only rb can supply — tautulli's, bazarr's and audiobookshelf's
  API keys, and the latitude/longitude the weather widget reads from sops. A
  ticket rather than a hand-off note because 38 wrote exactly this requirement
  as prose and closed anyway, leaving two widgets erroring for a month.
touches: [stacks/homepage/secrets.sops.env, stacks/homepage/config/widgets.yaml]
---

# 50 — Land homepage's five secrets and verify the reworked page

Blocked by: 39
Claimed by: claude session, 2026-08-08

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

### The five values

| var | where it comes from |
|---|---|
| `HOMEPAGE_VAR_TAUTULLI_KEY` | tautulli → Settings → Web Interface → API key |
| `HOMEPAGE_VAR_BAZARR_KEY` | bazarr → Settings → General → API key |
| `HOMEPAGE_VAR_AUDIOBOOKSHELF_KEY` | audiobookshelf → config → users → the admin account |
| `HOMEPAGE_VAR_LAT` | rb's coordinates, to ~4 decimal places |
| `HOMEPAGE_VAR_LON` | as above |

The audiobookshelf key arrived with [47](47-add-audiobookshelf.md) and is the
only one with a prerequisite: **the admin account does not exist until rb runs
the first-boot wizard**, so there is nothing to issue a key from until then.

`just secret homepage`, **never `sops --encrypt`** — outside a Stack directory it
finds no creation rule. The age key is at `age.key`, restored from KeePassXC.

The coordinates are secrets rather than settings because **the repo is public**
[39]. `common.env` already publishes the metro through `TZ`; these would publish
the house.

### The coordinates went in swapped, and west lost its sign

Landed 2026-08-07 as `LAT=123.458`, `LON=48.468`, and the weather widget showed
`API Error`. **Latitude is bounded at ±90**, so Open-Meteo rejected the request
outright — the pair is transposed, and the longitude is also missing its minus:
west of Greenwich is negative. `123.458°E` would put the box in the Sea of Japan,
which `TZ=America/Vancouver` contradicts.

Correct values: `HOMEPAGE_VAR_LAT=48.468`, `HOMEPAGE_VAR_LON=-123.458`.

**Corrected and verified 2026-08-07.** Not by range-checking a second time — that
is what let the first pair through the eye — but by making the call homepage
makes. Open-Meteo returned live data and **independently resolved the timezone to
`America/Vancouver`**, matching `common.env`, at 77 m elevation. A dropped sign
puts the box in the ocean, so a non-zero elevation is the cheap tell.

Diagnosed by decrypting and range-checking rather than by reading the error,
which says only `API Error` and names neither field. **Worth a validator?** Both
failures are mechanical — one bound check and one sign check against `TZ` — and
this is the second time a homepage secret has been wrong in a way nothing caught
[38]. Not ticketed; noted here in case a third makes the case.

### The coordinates were right and the widget still failed

Corrected values were committed and pushed, and weather still read `API Error`.
The container's environment held **neither** `HOMEPAGE_VAR_LAT` nor
`HOMEPAGE_VAR_LON` — so openmeteo was being handed the literal
`{{HOMEPAGE_VAR_LAT}}` string, and the coordinates were never the failing part
the second time.

`secrets.sops.env` was **not in `config_files`**. `DeployStackIfChanged` diffs
the compose file plus tracked files only, so a commit touching just the secret
diffed to nothing, no deploy ran, `pre_deploy` never re-decrypted, and the
container kept the environment it was created with. `secrets.env` on the box was
last written at 01:15:03 UTC — **one second before the container was created**,
and an hour before the coordinates existed.

Fixed by tracking it as `redeploy`, since `env_file` is read at creation and a
restart would not have helped either. The rule is now in
[conventions.md](../../../docs/conventions.md), *Tracked files*.

**This is the third time the same shape has bitten this Stack**: 38's keys were
never added, 39's CSS selector matched nothing, and this. All three are silent —
a green reconcile, a correct-looking repo, and a service reporting its own error
as though the value were wrong. The lesson is not about secrets; it is that
nothing here verifies that what git says arrived.

The other three Stacks holding secrets — caddy, calibre and download — have the
same untracked file: [51](51-track-secrets-in-remaining-stacks.md).

### homepage does not honour `style: row`, and the config is not the problem

The four groups rendered side by side as columns rather than stacked rows.
Everything that could be checked, checks out:

- `settings.yaml` **inside the container** carries `style: row` on all four.
- The server-rendered page payload carries
  `"Watch & Read": {"style": "row", "columns": 3}` — so homepage parsed it.
- `/api/services` returns group names byte-identical to the layout keys, which is
  what `index.jsx` matches on. Nothing is unmatched.
- `group.jsx` is identical at `v1.13.2` and `main`, so it is not a version skew.

Yet `.services-list` renders `flex flex-col`, which is the `style !== "row"`
branch. The likely mechanism is in `group.jsx`: `flex-1` and `basis-full` land on
the same element, `flex-1` is shorthand that also sets `flex-basis`, and Tailwind
emits the `flex` utility after `flexBasis` — so at equal specificity the group
never takes its full width.

Worked around in `custom.css` with an id-scoped override, mirroring homepage's
own `columnMap` breakpoints so the rule and the `columns: 3` setting cannot drift.
`maxGroupColumns` is **not** the knob — documented as applying "only for groups
with the default `style: columns`, not groups with `style: row`", minimum 5.

**Not verified rendering.** Services are client-rendered, so `curl` cannot show
the applied classes and nothing here could confirm it short of a browser. This is
the third CSS rule this ticket has shipped unseen; the first matched nothing at
all. Look at it before believing it.

### Then verify, because a green reconcile is not a running service

`compose.yaml` gained two read-only binds, so this is a **recreate**, not a
restart — `config_files` covers the config half but the compose change is what
Komodo diffs. Check the workload, not the update log.

Confirmed live 2026-08-07 against the served page: all four groups render
(`Watch & Read`, `Acquire`, `Transport`, `Infrastructure`), the resources block
carries **five** readouts, and all four header widgets are present. The array
showed 24.6 TB free and the cache 893 GB — the binds took, so the overlay bug is
gone. What is left below is what only an eye can settle.

- The header reads **resources / weather / clock**, with **search on its own row
  below** — revised from the order first written [39].
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
