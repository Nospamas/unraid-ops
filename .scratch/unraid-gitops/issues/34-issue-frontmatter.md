# 34 — Retrofit frontmatter onto the closed issues

Type: task
Status: open
Blocked by: —
Claimed by: Claude session, 2026-08-06

## Question

The issues are this repo's documentation of why it looks the way it does, but
they are expensive to triage: finding the one that explains a file means opening
several that don't. Give each one a header cheap enough to read in bulk.

### The schema

Settled while charting — implement it, do not re-litigate it.

```yaml
---
id: 23
title: Migrate plex
type: task
status: closed
description: >
  plex is a Stack on `shared`; adopting in place recreates under a new
  container name, keeping the network alias. VERSION must be `docker` or the
  container installs a Plex build over the image at every start.
touches: [stacks/plex/, docs/adding-a-service.md]
---
```

- **`description` is the gist, not the question.** These issues are closed, so
  the reason to open one is its answer. Two or three lines. It is the field that
  decides whether the body gets loaded, which is the whole point.
- **`touches` inverts the index.** Repo-relative paths this ticket's decision
  explains. Today, finding out why [caddy's compose](../../../stacks/caddy/compose.yaml)
  is host-networked requires knowing that [16](16-deploy-caddy.md) exists; with
  `touches`, grepping the path finds it.
- **`type` and `status`** so a set can be filtered without reading.

Three fields were considered and left out on purpose — do not add them back
without a reason on this ticket:

- **dates** — git has them, and a hand-written one goes stale on first edit
- **`blocked-by`** — already in the bodies, and every ticket bar one is closed;
  a second copy of a dependency graph is a graph that disagrees with itself
- **tags** — `touches` does the real work, and a taxonomy nobody maintains is
  worse than none

### The work

- 32 existing issues, plus the map-02 tickets as they are written.
- **[29](29-alerting-on-failed-reconcile.md) reads `Status: resolved`** where
  every other closed issue reads `Status: closed`. Fix it — a status grep
  currently lies. Check for other drift while sweeping.
- The `Type:` / `Status:` / `Blocked by:` lines in the bodies are now duplicated
  by frontmatter. Decide whether they go or stay, and apply it uniformly.

No index recipe. `grep` over the frontmatter is enough, and a generated index is
another thing to keep working.

## Hand-offs

None.
