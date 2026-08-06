# 33 — Migrate map 01's standing content, and stand up the open-questions register

Type: grilling
Status: open
Blocked by: —
Claimed by: Claude session, 2026-08-05

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

## Hand-offs

None expected — this ticket edits files in the repo only.
