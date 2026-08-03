# 28 — Make the repo's standing docs navigable, and auto-loaded

Type: task
Status: open

## Question

Raised by the human during [27](27-recipe-safety-convention.md), while deciding
where a new convention should be written down. The convention went into
[docs/repo-layout.md](../../../docs/repo-layout.md) because that is where
standing rules already live — but the human's objection to that file was not
about fit:

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
