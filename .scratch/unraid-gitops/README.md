# The tracker

Wayfinder maps and their issues. A map charts the way to a destination; its
issues are the decisions along it. This file is the machinery — what those files
are allowed to hold, and the conventions that keep them cheap to read.

The repo's own standing rules are not here. [CLAUDE.md](../../CLAUDE.md) is
auto-loaded and points at [CONTEXT.md](../../CONTEXT.md),
[docs/conventions.md](../../docs/conventions.md) and
[docs/adding-a-service.md](../../docs/adding-a-service.md).

```
README.md              this file
map.md                 the live map
map-01-foundation.md   archived, still read
open-questions.md      deferred, outlives any one map
issues/                one file per decision
assets/                what an issue produced
```

## What a map may contain

Destination, notes that are **pointers rather than content**, a one-line index
of closed issues, fog, and scope boundaries. Nothing else.

Both of map 01's long sections grew because the map was the only place a fact was
guaranteed to be read [28](issues/28-navigable-standing-docs.md). That stopped
being true when CLAUDE.md became
auto-loaded, and the division it established holds: **rationale lives in the
issue, the doc holds the rule plus a `[NN]` citation.** A map that starts
explaining is a doc that nobody indexed.

**Do not add a fifth standing doc.** Map 01's ruling, and it survives
[33](issues/33-migrate-map-01-standing-content.md).

## The index and the description are one sentence

A closed issue's `description` frontmatter and its line in the map's
**Decisions so far** say the same thing. Write it once and copy.

Where they disagree the **issue wins** — it sits next to the reasoning, and the
map line is a pointer. The map keeps its own copy because an index has to be
readable top to bottom, in the order the route was walked, which a field
scattered across forty files is not.

## An issue

Frontmatter per [34](issues/34-issue-frontmatter.md) — `id`, `title`, `type`,
`status`, `description`, `touches`.
`description` is the gist, so an issue can be triaged without opening it;
`touches` inverts the index, so a path greps back to the issue that explains it.

**Frontmatter and the body header never state the same fact.** The header under
the title holds only what the schema refuses: `Blocked by:`, `Resolved:`,
`Asset:`, and the claim below. `Type:` and `Status:` there are the frontmatter's
job now [34].

**Claim one before working it.** Sessions run in parallel and this tracker has no
assignee field, so add a line to the issue and **commit it first**, before any
other work:

```
Claimed by: <session or human>, <date>
```

An open issue with no `Claimed by:` line is unclaimed. Clear the line if the
session ends without resolving it, or the issue looks taken and is not.

## Where a question goes when it outlives a map

[open-questions.md](open-questions.md) — deferred, belonging to no current map.
Each entry is the question, the **trigger** that would make it sharp enough to
ticket, and its citations.

Deferred is not ruled out. A question decided *against* belongs to the map that
decided it, in its **Out of scope** section, and stays there.

## The archive

A map whose destination is reached is archived in place, not gutted. Map 01
remains the fullest account of the two networks, the box's access rules and the
questions this repo has ruled against — none of that was copied forward, because
a session only needs it when it is already reading about that ground.
