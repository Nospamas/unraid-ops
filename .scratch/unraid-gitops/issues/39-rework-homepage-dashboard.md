---
id: "39"
title: Rework the homepage dashboard
type: prototype
status: open
description: >
  Make `home.rbrb.in` the page rb opens by choice: grouping, what deserves a
  widget, bookmarks and theme. The destination's only subjective clause —
  worked with the human, back and forth, and it cannot be closed alone.
touches: [stacks/homepage/config/]
---

# 39 — Rework the homepage dashboard

Blocked by: 38, 40

## Question

Make `home.rbrb.in` the page rb opens by choice rather than one he has bookmarks
around. This is the destination's only subjective clause, and it is deliberate:
**this ticket is worked with the human, back and forth, and cannot be closed
alone.**

By the time it starts, [38](38-homepage-tile-gaps.md) has every service on the
page with a working widget and [40](40-survey-complementary-services.md) has
settled whether anything is still missing. So this session spends its time on
judgment, not data entry.

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

## Hand-offs

The whole ticket is a hand-off; it is a conversation, not a checklist.
