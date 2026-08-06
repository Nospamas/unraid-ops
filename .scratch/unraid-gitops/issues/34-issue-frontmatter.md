---
id: "34"
title: Retrofit frontmatter onto the closed issues
type: task
status: closed
description: >
  All 42 issues carry `id`/`title`/`type`/`status`/`description`/`touches`, so a
  set can be filtered without reading and a repo path greps back to the issue
  that explains it. The body header keeps only what the schema deliberately
  refuses — the blocking edge, the claim, the date and the asset.
touches: [.scratch/unraid-gitops/README.md]
---

# 34 — Retrofit frontmatter onto the closed issues

Resolved: 2026-08-06
Blocked by: —

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

## Resolution (2026-08-06)

**All 42 issues carry the schema, and the body header keeps exactly what the
schema deliberately refuses.** That is the rule the open question resolves to:
frontmatter and body never state the same fact.

| | |
|---|---|
| gone from the body | `Type:`, `Status:` — duplicates now |
| gone entirely | `Assignee:` — `Nospamas` on 30 files, absent on the other 12, and the `Claimed by:` line is the live mechanism |
| kept in the body | `Blocked by:`, `Resolved:`, `Asset:`, `Claimed by:` |

`Blocked by:` had to stay: the schema excludes it *because* it is in the bodies,
so deleting it deletes the dependency graph. `Resolved:` stays for the same
reason the schema rejects it — a date field maintained by hand goes stale, but
these are already written and already true, and dropping 26 recorded dates to
tidy a header is not a trade.

**`id` is zero-padded and quoted — `id: "07"`.** The schema example wrote
`id: 23`, which is silent on the first nine, and there the padding is the whole
point: `07` is the token the filenames and every `[NN]` citation use, `7` is not.
Bare `07` is also ambiguous YAML, so the quotes are load-bearing rather than
cosmetic. `type: task (HITL)` on seven issues normalised to `task`; the schema's
own value list has no such member, and who drove a ticket is in its body.

### The descriptions were not written fresh

Each map's index line is the source, per the tracker's
[one-sentence rule](../README.md) — map 02's copied verbatim for
[25](25-retire-portainer.md) and [33](33-migrate-map-01-standing-content.md),
map 01's condensed for everything before them, since several of its lines run to
eight and the schema asks for two or three.

**Map 01 was not edited to match.** [33](33-migrate-map-01-standing-content.md)
archived it in place, and rewriting thirty index lines to satisfy a convention
invented after it closed is exactly the gutting that ruling refused. So where the
archive is fuller than the description, the description carries the lead claim
and the archive keeps the rest — the two agree, one is shorter.

### Drift found

- **[29](29-alerting-on-failed-reconcile.md)'s `Status: resolved`**, as this
  ticket predicted. Now `closed`.
- **Seven closed issues carried no `Resolved:` date** — 08, 11, 12, 19, 20, 29,
  32. Backfilled from each one's own resolution heading, and for 12 and 19 from
  the commit that closed them.
- **`touches` was mostly not guesswork**: every script in
  [scripts/](../../../scripts/) names its ticket in its header comment, so the
  inversion already half existed. Every non-glob path was checked to exist; the
  one glob, `stacks/*/secrets.sops.env`, is quoted because `*` opens a YAML
  alias.

**A frontmatter grep still lies once, and it is this file.** The schema example
above is a real frontmatter block in a fenced code block, so
a frontmatter grep counts one closed issue more than exists. Anchor to the head
of each file, or know the one false positive.

## Hand-offs

None.
