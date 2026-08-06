# 33 — Migrate map 01's standing content, and stand up the open-questions register

Type: grilling
Status: closed
Blocked by: —
Resolved: 2026-08-06

## Question

[map-01-foundation.md](../map-01-foundation.md) is 511 lines, of which 215 are
**Notes** and 190 are **Decisions so far**. Both grew because the map was the
only place a fact was guaranteed to be read. That is no longer true —
[CLAUDE.md](../../../CLAUDE.md) is auto-loaded, and
[28](28-navigable-standing-docs.md) already established the division: **rationale
lives in the ticket, the doc holds the rule plus a `[NN]` citation.**

Decide where each block of map 01's Notes lands, and write down the rule that
keeps map 02 from growing the same way.

### The candidate destinations

| target | what belongs |
|---|---|
| [CLAUDE.md](../../../CLAUDE.md) | auto-loaded, so every line costs context in **every** session. Only what an agent must not get wrong unprompted. |
| [CONTEXT.md](../../../CONTEXT.md) | vocabulary — the words this repo uses and the ones it doesn't |
| [docs/conventions.md](../../../docs/conventions.md) | the standing rules, indexed by section |
| [docs/adding-a-service.md](../../../docs/adding-a-service.md) | the routine — steps and templates |
| the ticket that raised it | rationale. Usually already there; the map was restating it. |
| [open-questions.md](../open-questions.md) | deferred, belongs to no current map |
| dropped | phase-one narration with no future reader |

**Do not add a fifth doc.** That ruling is map 01's and it survives this ticket.

### The blocks to place

- The **two networks** table, and the LAN resolver story ([32](32-lan-resolver.md))
- **Box access** — SSH, port 8008, no out-of-band console, the "state the
  rollback" rule. Some of this is already in CLAUDE.md; decide whether the rest
  joins it or thins out.
- **Komodo is live** — credentials, `files_on_host` under
  `/mnt/user/appdata/komodo`, pre-created and chowned bind targets, Periphery's
  binds bounding what `pre_deploy` can see, a Procedure that cannot update itself
- **Standing rulings** — surface the hand-offs, container scope closed, secret
  severity, permissions, a green reconcile is not a running service, one Service
  is published, add one Stack to the deploy pattern at a time
- **Settled while charting**

Map 01's **Decisions so far** is the easier half: it becomes derivable once
[34](34-issue-frontmatter.md) lands, because every entry is a restatement of an
answer the issue itself will carry in its `description`. Say so explicitly rather
than copying it forward.

### The register

Stand up [open-questions.md](../open-questions.md) and seed it with map 01's six
**Not yet specified** entries, each naming the map that raised it:

- reconciling on push rather than a 15-minute timer
- appdata backup and box rebuild
- authentication in front of the services
- what a moved DHCP lease costs
- home-network devices that are not on the tailnet
- knowing the box itself is gone (blocked on `~/home-ops`)

None is ruled out; all are deferred. The register exists so that distinction
stays visible — **Out of scope** means decided against, and filing these there
would be a lie the next reader believes.

### The rule to write

What is a map allowed to contain? The working answer this ticket should test and
record: **destination, notes that are pointers rather than content, a one-line
index of closed tickets, fog, and scope boundaries — nothing else.** Where that
rule belongs is itself part of the decision.

## Resolution (2026-08-06)

**The ticket asked the wrong question.** It assumed map 01's Notes had to be
*relocated* before the file stopped being read. But nothing forces the file to
stop being read — it is in the repo, it is linked from the live map, and an
archive costs nothing until someone opens it. So the ruling is: **map 01 is
archived in place, not gutted**, and the migration is only what a session would
get wrong *without ever having reason to open it*.

That test is the reusable part. Applied to the five blocks, four of them
collapsed:

| block | outcome |
|---|---|
| Komodo is live | **already migrated.** [bootstrap/README.md](../../../bootstrap/README.md) carries the credentials, `create-if-absent`, the do-not-change-it-in-the-UI trap and the rate limit, in more detail than the map did; `files_on_host` and pre-created bind targets are in [conventions.md](../../../docs/conventions.md)'s `pre_deploy` section. |
| Standing rulings | permissions, the green-reconcile trap, plex's publication, adoption-splits-by-manager and container scope are all in conventions.md via [28](28-navigable-standing-docs.md). "Add one Stack at a time" was adoption-era and nothing is left to adopt. |
| Box access | CLAUDE.md already has SSH, port 8008, no out-of-band console and the state-the-rollback rule. The residue is the key path and "no live lockout risk remains"; Portainer-as-second-lifeline died with [25](25-retire-portainer.md). Archived. |
| Settled while charting | already in [CONTEXT.md](../../../CONTEXT.md) and CLAUDE.md. |
| Two networks + the LAN resolver | the *rule* is in conventions.md's **Addressing** [32]. The **trap** was not. |

### What actually moved, and why each earned it

- **Verify a hostname from the LAN path, not the tailnet** →
  [conventions.md](../../../docs/conventions.md), Addressing. A node with
  `--accept-dns` never asks rb's router, so an `rbrb.in` check from `ubuntu-dev`
  passes whether the LAN half works or not. This has a track record: it is how
  "conveniently, there is no resolver to configure" survived unchallenged for a
  whole map. A session verifies without being told to; it will not be told to
  read the archive first.
- **Surface the hand-offs** → [CLAUDE.md](../../../CLAUDE.md), a new
  *Ending a session* block. Session behaviour, stated nowhere in the repo, and
  the failure is silent — [13](13-local-tooling.md)'s Renovate config sat inert
  waiting on one click.

### Ruled against stays with the map that ruled it

pihole, rotating the low-value secrets, and the repo's visibility are **not
carried**. They are not hard rules and nothing re-raises them except a session
already working that ground, which is a session already reading map 01. This is
the same shape as the one ruled-against entry that *did* survive into the docs —
hardlinks, at [09](09-unify-uid-gid.md) — which survives by being attached to
the media binds it governs, not by living in a register. A register of closed
questions was considered and declined: it is a fourth kind of thing
conventions.md would hold, and a reader deciding about DNS has to already know
the register exists to find the pihole line.

### The register

[open-questions.md](../open-questions.md) is live with map 01's six entries.
Each is the question, the **trigger** that would make it sharp, and its
citations — not the accumulated reasoning, which is in the tickets it cites. The
trigger is the load-bearing part: five of the six already ended in some form of
"not a ticket before then", and that sentence is the only part *not* recoverable
from the cited tickets, since those tickets argued the question was out of scope
rather than what would bring it back.

### The rule, and why not ADRs

The rule lives in **[.scratch/unraid-gitops/README.md](../README.md)** — a
README for the directory it governs, following
[bootstrap/README.md](../../../bootstrap/README.md)'s precedent. It holds four
things that had no home: what a map may contain, the index-and-`description`
overlap, the claim convention and frontmatter schema (both **moved out of** the
live map's Notes rather than duplicated), and where a question goes when it
outlives a map.

**ADRs were raised and declined for now.** This repo already has them — every
issue in this directory is context, decision, rationale and consequences, dated
and closed, cited as `[NN]` from the docs, and [34](34-issue-frontmatter.md) is
about to give them ADR metadata. The test for minting a *separate* series is
whether a decision has **no ticket and no thing to attach to**. Exactly four
qualify, all settled in passing while charting, and four items do not justify a
second numbered series with its own lifecycle — two places to file a decision is
worse than one place plus a gap. **The trigger that would flip this**: if
`.scratch/` is ever cleaned up or the maps end, these issues become the repo's
only record of why the box looks the way it does, and a series living outside a
scratch directory starts earning its keep. The README is the thing that becomes
`docs/decisions/` if that day comes, and nothing else has to move.

### Map 01's Decisions so far

Not copied forward, as the ticket asked. Every entry is a restatement of an
answer the issue itself will carry in its `description` once
[34](34-issue-frontmatter.md) lands. The README states the rule that keeps the
two from diverging: they are **one sentence**, written once and copied, and
where they disagree the issue wins.

## Hand-offs

None — this ticket edited files in the repo only.
