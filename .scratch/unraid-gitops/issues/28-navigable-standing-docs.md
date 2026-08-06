---
id: "28"
title: Make the repo's standing docs navigable, and auto-loaded
type: task
status: closed
description: >
  `repo-layout.md` is now docs/conventions.md, indexed and cut 434 → 280
  lines, with CLAUDE.md finally giving the repo something auto-loaded. The
  reusable part is the division: rationale lives in the ticket, the doc holds
  the rule plus a `[NN]` citation.
touches: [CLAUDE.md, docs/conventions.md]
---

# 28 — Make the repo's standing docs navigable, and auto-loaded

Resolved: 2026-08-03

## Question

Raised by the human during [27](27-recipe-safety-convention.md), while deciding
where a new convention should be written down. The convention went into
`docs/repo-layout.md` — now [docs/conventions.md](../../../docs/conventions.md)
— because that is where standing rules already live, but the human's objection
to that file was not about fit:

> repo layout is getting quite long, I'm concerned with it blowing up your
> context every time. Lets improve how concise it is and add an index so that
> you can read the right sections on each issue. Maybe it would be better held
> as repo-conventions or something like that (layout seems like a very specific
> term)

Two problems, and they are separable:

**1. The file is long and unindexed.** `docs/repo-layout.md` is ~440 lines with
**17** `###` sections under `## Conventions`, and the only way to find the one
that matters is to read all of it. A ticket that needs the ports convention pays
for the media-paths reasoning too. It also isn't really a *layout* document any
more — the tree is one section out of eighteen.

**2. Nothing in this repo is auto-loaded.** The instruction "read
[CONTEXT.md](../../../CONTEXT.md), repo-layout.md and
[docs/adding-a-service.md](../../../docs/adding-a-service.md) before touching a
service" lives in the **map's Notes** — which is `.scratch/`, scoped to this
effort, and evaporates when the map closes. A future session, or the human in
six months, gets no such prompt. `CLAUDE.md` does not exist; `.claude/` holds
only `settings.local.json`.

What has to be decided:

- **The rename.** `docs/repo-conventions.md` is the human's suggestion and reads
  right. **74 references across 25 files** point at the current name, and 22 of
  those files are *closed tickets* — a record of what was decided at the time.
  Sweeping their links edits the record; leaving them breaks it. Which of those
  is acceptable is a decision, not a chore. (A third option: leave a stub at the
  old path.)
- **The index, and what it indexes.** A table at the top mapping section → when
  you need it. If that works, the file could stay one file; if it doesn't, the
  conventions split across several and the index becomes the file.
- **The concision pass.** Much of the length is *rationale* — why media binds
  are per-category, why `pre_deploy` repeats in eleven files — and that rationale
  is load-bearing precisely because it stops someone "tidying" it away. Cutting
  it is not free. Where the reasoning belongs (the doc, or the ticket the doc
  links) is the actual question.
- **`CLAUDE.md`.** Recommended in 27 as a **thin table of contents with teeth**:
  pointers to the three docs, plus the handful of rules that are expensive to
  violate by accident — never widen the deploy pattern to `*`, `--apply` gates
  out-of-band box changes, every image is `version@digest`, nothing is built on
  the box, nothing faces the internet without `x-published`. Deliberately *not*
  a summary. This repo has already been bitten twice by docs drifting from
  reality: [07](07-repo-layout-and-conventions.md)'s checklist had three defects
  [08](08-deploy-homepage.md) found and one [13](13-local-tooling.md) found. A
  fourth file that restates the other three is a fourth thing that can go stale.
- **Whether [adding-a-service.md](../../../docs/adding-a-service.md) folds in**
  (198 lines) or stays a separate checklist.

**Not a decision:** the content of the conventions themselves. This ticket moves
and shapes what 07, 08, 09, 12, 13 and 27 already settled — it does not reopen
any of it. If the pass finds a convention that is *wrong*, that is a new ticket,
not a rewrite in passing.

**Type is `task`, not `grilling`**, because the decisions are taxonomy and are
better made with the whole file open than in conversation.

Blocks nothing. Nothing blocks it — but the longer it sits the more there is to
move: [16](16-deploy-caddy.md) and the migrations
[21](21-migrate-arr-stacks.md)–[24](24-migrate-download-stack.md) all write into
these docs.

## Resolution (2026-08-03)

Five decisions, then the pass.

**1. Renamed to [docs/conventions.md](../../../docs/conventions.md), all 89
references swept.** The ticket framed the sweep as *editing the record*; it
isn't. A markdown link is an **address**, not a quotation — updating one keeps
the record usable, and the decision text in every closed ticket is untouched. The
stub-at-the-old-path option was declined: this repo's named hazard is docs
drifting from reality, and a permanent tombstone file is one more thing that can
rot. The rename is recorded **once**, in the new file's footer.

`docs/conventions.md`, not the suggested `docs/repo-conventions.md` — it already
lives in `docs/`, so `repo-` stutters at every call site.

Two spots were **deliberately left saying `repo-layout.md`**: this ticket's own
Question, where the old name is the subject rather than an address, and the
prose mentions in [08](08-deploy-homepage.md), which describe what the file
claimed at the time.

**2. One file with an index, not a `docs/conventions/` split.** The index is a
`read | when` table over 15 sections, and it works because the concision pass
made the whole file cheap: **434 → 280 lines**, and a section is now ~14 lines.
A split would have traded "find the section" for "find the file" plus a lot of
cross-linking, for a file that no longer needs rationing.

**3. Rationale moved to the tickets, and the doc keeps a guard where the rule
looks wrong on its face.** This was the ticket's real question. The answer is a
division: the ticket holds the argument, the doc holds the rule plus a `[NN]`
citation, and where a convention invites tidying it keeps **one line** saying not to
— the media binds, `pre_deploy`'s eleven-fold repetition, the absent
`bootstrap/komodo.toml`. The `[NN]` shorthand is what made the density possible:
`[ticket 07](07-repo-layout-and-conventions.md)`
inline, twenty-odd times, was itself a meaningful share of the line count.

**`[NN]` is a plain citation, not a link**, and the human caught the first
attempt at making it one. Reference-style definitions at the foot cost 14 lines
and a rendering inconsistency — `[[12]]` and `[21]` do not produce the same
markup — to hyperlink a directory that sits one level up and is named
predictably. The header states the path pattern once instead.

A second division fell out and is worth keeping: **`conventions.md` states the
rule, `adding-a-service.md` holds the template to copy.** Five compose/TOML
blocks were verbatim in both files; they now live only in the routine.

**4. [CLAUDE.md](../../../CLAUDE.md) exists, 47 lines, and is deliberately not a
summary.** Pointers to the three docs, the eight rules that are expensive to
break by accident, and the box-access warning. Every line is either a pointer or
a rule that costs an outage — nothing that restates a convention, because the
ticket is right that a fourth file restating the other three is a fourth thing
that can go stale. It resolves problem 2: the "read these three files first"
instruction now lives in the repo rather than in this map's Notes, which
evaporate when the map closes.

**5. [adding-a-service.md](../../../docs/adding-a-service.md) stays separate**
(198 → 172 lines). Different mode of use: the routine is read start-to-finish
while doing a thing; the conventions are looked up one section at a time. Folding
them would have put an eight-step checklist inside an index.

### Three stale facts fixed in passing

Factual drift, not conventions reopened — the ticket's carve-out holds.

- The tree said **"Twelve Stacks, thirteen containers"**. It is eleven and
  twelve. The tree also lacked `scripts/host.sh` and `bootstrap/host/`, both
  added by [15](15-move-unraid-gui-ports.md).
- An **"Unverified"** callout warned that `additional_env_files = ["../../
  common.env"]` might not resolve from a Stack directory.
  [11](11-stand-up-komodo.md) verified it months of tickets ago; the callout
  outlived its own answer.
- [CONTEXT.md](../../../CONTEXT.md) said **"Only three Stacks have one"** of
  secrets (four do) and that bootstrap is **three containers** (four, since 11
  put the DB on FerretDB-on-Postgres). Both counts are now gone rather than
  corrected — `ls stacks/*/secrets.sops.env` answers the first, and a count in
  prose is a thing that goes stale for nothing.

`just lint` passes. Nothing on the box changed; no new secrets.

### Addendum: the map itself (same session)

The human extended the pass to [map 01](../map-01-foundation.md), which had the same disease
and worse: **614 → 217 lines.** Decisions-so-far had grown into seventeen
15-to-30-line essays restating what the tickets already hold — a direct
violation of wayfinder's own rule that the map is an *index*, not a store. Each
is now one or two sentences: enough to judge relevance, then open the ticket.

Notes shrank by pointing rather than repeating. Four whole blocks — *Never build
an image*, *The loop is live*, most of *Local tooling*, *Default-private* — were
duplicating what this ticket had just put in `conventions.md` and `CLAUDE.md`,
so they became a single pointer to those files with a **do not restate the rules
here** attached. What survives in Notes is what genuinely has no home in the
repo: box access and the lockout posture, Komodo's live credentials and API
habit, the hand-off rule, and the secret-severity ruling that exists to stop
rotation being re-raised.
