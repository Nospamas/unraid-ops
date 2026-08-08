---
id: "39"
title: Rework the homepage dashboard
type: prototype
status: closed
description: >
  The page is a launcher, not a status board — so gatus stays a tile rather
  than a header summary. Groups cut by use vs machinery, three columns, and a
  header row of resources/search/weather/clock whose disk figure is real for
  the first time: nothing was ever mounted, so it had been reading the
  container's own overlay.
touches: [stacks/homepage/config/, stacks/homepage/compose.yaml]
---

# 39 — Rework the homepage dashboard

Resolved: 2026-08-07
Blocked by: 38, 40, 45

## Question

Make `home.rbrb.in` the page rb opens by choice rather than one he has bookmarks
around. This is the destination's only subjective clause, and it is deliberate:
**this ticket is worked with the human, back and forth, and cannot be closed
alone.**

By the time it starts, [38](38-homepage-tile-gaps.md) has every service on the
page with a working widget and [45](45-pick-from-the-survey.md) has settled
whether anything is still missing — [40](40-survey-complementary-services.md)
only surveyed, and deliberately left the picking to a conversation. So this
session spends its time on judgment, not data entry.

**Three tiles are coming and this ticket does not wait for them.** 45 picked
audiobookshelf ([47](47-add-audiobookshelf.md)) and unpackerr
([48](48-add-unpackerr.md)), both of which get a widget, and recyclarr
([46](46-add-recyclarr.md)), which gets **no tile worth having** — it is headless,
so there is nothing for a widget to show. Lay out for the two, and let 46 decide
whether a headless Stack appears on this page at all.

### What is open

- **Grouping and layout.** [settings.yaml](../../../stacks/homepage/config/settings.yaml)
  has four groups — Media, Downloads, Books, Infrastructure — set before gatus,
  ntfy, CoreDNS, Caddy or tautulli existed. Do they still carve it at the joints,
  and does everything belong in a group at all?
- **What deserves a widget.** Every widget is a live call to a service. A page of
  them is noise and load; the question is which three or four answer something rb
  actually wonders.
- **[widgets.yaml](../../../stacks/homepage/config/widgets.yaml) is three entries** —
  resources, datetime, search — and has never been revisited. No array or disk
  widget, nothing surfacing gatus at the top of the page.
- **[bookmarks.yaml](../../../stacks/homepage/config/bookmarks.yaml) has one entry**,
  the Unraid forums, and is empty by default rather than by design. This is the
  "missing useful links" half.
- **Theme.** `Tower`, dark, slate, `headerStyle: clean`. Never chosen against an
  alternative.

### How to work it

Use `/prototype`. Homepage's config is git-owned and reloads on a push, so the
loop is fast — but it is also the **only** service whose config git owns, so a
broken YAML is a broken dashboard until the next reconcile. Iterate locally
where possible.

**`/app/config` must stay writable** — homepage seeds missing skeleton files at
boot and serves HTTP 500 if it cannot. Keep the skeleton complete in the repo so
nothing is seeded untracked into the clone; that is why an empty
`bookmarks.yaml` is tracked at all.

Anything that turns out to need a *new service* is not this ticket — it is a new
one, off the back of [40](40-survey-complementary-services.md).

## Answer

**The page is a launcher; status is secondary.** rb's words: gatus is the better
target for uptime. So the header carries **no gatus summary** — the idea the
question raised is declined, because it would be a second, worse copy of a page
that already exists and is one click away. gatus keeps its tile.

Every open item, decided:

- **Grouping — cut by use vs machinery, not by subject.** `Watch & Read` /
  `Acquire` / `Transport` / `Infrastructure`. The old `Media` held plex beside
  the five services that feed it, and nothing on the page said which one you
  wanted. **`Books` dissolves**: calibre is something you open, lazylibrarian is
  something that fetches, and they no longer sit together. Three columns, not
  four — `Acquire`'s five tiles wrap 3+2 rather than cramming.
- **Widgets — all ten kept.** The cull this ticket expected did not happen; rb
  wanted the density. See the defect below, which is what keeping them costs.
- **Header row — `resources` / `search` / `openmeteo` / `datetime`.** Weather is
  new. `search` carries Tailwind's `grow`, so at position two it absorbs the
  slack and pushes weather and the clock right with no width set anywhere.
- **Bookmarks — off-box companions only**, six entries in `Ops` and `Reference`,
  verified with rb before writing. The rule that earns them their place: a
  bookmark holds what a tile cannot, so nothing there runs on this box.
- **Theme — unchanged, and still not chosen against an alternative.** rb will
  judge `color: zinc` on the live page rather than a swatch. One line in
  `settings.yaml`.

### The disk figure was never real

`widgets.yaml` read `disk: /` and `compose.yaml` bound **no host filesystem**, so
for its whole life that number was the container's own overlay — the image, a
constant. homepage's resources widget "recognizes mounted container volumes
only". Fixed with two read-only binds and `disk:` as an **array**, which is what
lets the array and the cache pool sit in one block as two readouts.

`/mnt/user0` is not the second figure: `df` reports it identically to
`/mnt/user`, 59T at 62%. The array and the 932G NVMe cache pool are the two real
ones.

### Two widgets 38 added have never worked

`services.yaml` references `HOMEPAGE_VAR_TAUTULLI_KEY` and
`HOMEPAGE_VAR_BAZARR_KEY`; `secrets.sops.env` holds four vars and neither is
among them. `secrets.env` is the only source — `komodo.toml` adds just
`common.env` — so both widgets have been erroring on the live page since
[38](38-homepage-tile-gaps.md) closed. 38's own **Do not forget** section names
this exact requirement, which is the point: **it was written as prose and prose
does not block a close.** Hence [50](50-homepage-secrets-and-verify.md) rather
than another line of prose here.

### Coordinates are a secret, not a setting

rb's call, and better than either option offered. The repo is **public**
(`"private": false`), so hardcoded lat/long publishes his home to ~100m —
`common.env` already gives away the metro via `TZ`, but not the house. Browser
geolocation would have avoided git entirely at the cost of a permission prompt
per device. sops gets both: encrypted in git, no prompt, identical everywhere.
Verified this works — homepage substitutes `HOMEPAGE_VAR_*` into **any** config
file, not just `services.yaml`.

### Spacing

`custom.css`, not `headerStyle: boxedWidgets` — the ask was room, not cards.
homepage's docs say only that "various classes / ids" exist and **list none of
them**, so the selectors were read off the running page. `#widgets-wrap` carries
Tailwind's `gap-x-2` and an id outranks a class, so widening the gap is one
property and needs no `!important`. A version bump can still rename it; nothing
would catch that but the eye.

## Hand-offs

Tracked as [50](50-homepage-secrets-and-verify.md), not left here — see above.
