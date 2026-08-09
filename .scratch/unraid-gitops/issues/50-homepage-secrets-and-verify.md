---
id: "50"
title: Land homepage's five secrets and verify the reworked page
type: task
status: closed
description: >
  All five landed and all ten widgets verified returning live data — but only
  after three silent failures, two of them in the delivery rather than the
  values. The check that finally settled it is homepage's own widget proxy,
  callable from the box per service, which is what nothing had been doing.
touches:
  - stacks/homepage/secrets.sops.env
  - stacks/homepage/config/widgets.yaml
  - stacks/homepage/config/custom.css
  - stacks/homepage/komodo.toml
---

# 50 — Land homepage's five secrets and verify the reworked page

Resolved: 2026-08-08
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

## Answer

All five values are in, and the running container carries all nine
`HOMEPAGE_VAR_*`. It was created **16 seconds after** the commit that added the
audiobookshelf key — the `redeploy` tracking above working as intended, where
before it was the whole failure.

### The check that was missing is homepage's own proxy

Every widget call goes through `/api/services/proxy`, server-side, so it can be
made from the box without a browser:

```sh
curl -H 'Host: home.rbrb.in' \
  'http://<homepage-ip>:3000/api/services/proxy?group=<group>&service=<service>&endpoint=<endpoint>'
```

The `Host` header is not optional — homepage rejects anything else with *Host
validation failed*. The endpoint names are not documented; they are the second
argument to `useWidgetAPI` in each `/app/src/widgets/<type>/component.jsx`.

All ten swept 2026-08-08, all returning live data: **tautulli** `get_activity`
(0 streams), **bazarr** `episodes`/`movies` (`total: 0`), **audiobookshelf**
`libraries` (the `Audiobooks` library), plus plex, sonarr, radarr, prowlarr,
qbittorrent, gluetun, gatus and ntfy. rb confirmed all three new tiles render
that data rather than an error.

**This answers the ticket's own complaint** — *nothing here verifies that what
git says arrived*. Two of this Stack's three silent failures would have been
caught by that one sweep: 38's missing keys, and the untracked-secret one above.
It does not catch 39's CSS selector matching nothing, which stays an eye
problem. Ticketed as [55](55-verify-the-widgets-from-the-box.md).

The **coordinate validator** floated above is not worth building separately: the
information widgets answer on `/api/widgets/<type>` on the same terms, and
`resources?type=disk&target=/mnt/user` returned 64 TB at 61.6% — proving the
disk binds took, server-side, which 39 could only confirm by eye. `openmeteo` is
the one that resists, because the client passes the coordinates as query
params rather than the server reading them from config.

### The two things only an eye could settle

- **Theme — `zinc`, chosen.** rb judged it on the live page against slate. The
  one line on the dashboard nobody had ever picked is now picked.
- **The `style: row` override works.** One group per row, three columns wide —
  so the fourth CSS rule this Stack shipped unseen is the first to be looked at,
  and it holds. `#layout-groups > .services-group { flex-basis: 100% }` is doing
  what `style: row` would have.

### Correction: four readouts, not five

`uptime` was dropped from `widgets.yaml` after the verification list above was
written, so the resources block is cpu, memory and two disks. `custom.css`'s
comment still claimed five and has been corrected.

## Hand-offs

None. Every step needed rb and every step is done.
