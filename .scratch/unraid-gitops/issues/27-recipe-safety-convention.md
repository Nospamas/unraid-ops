# 27 — Make every mutating `just` recipe dry-run by default

Type: grilling
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03

## Question

Raised by the human during [15](15-move-unraid-gui-ports.md), which shipped
`just host-ports` — a recipe that moves the port the Unraid GUI answers on. It
was made **dry-run by default, `--apply` to commit**, and the human asked for
that to be the rule for *all* recipes rather than a one-off on the dangerous
one.

The ask is that no `just` recipe can change the box by accident. Nothing about
the current set says which ones can; `just --list` reads as a flat menu, and
`reconcile` looks no more consequential than `lint`.

Where the recipes stand today:

| recipe | reaches | mutates |
|---|---|---|
| `default`, `lint`, `verify-secrets`, `host-check` | local / read-only | no |
| `secret <stack>` | repo file, via `$EDITOR` | repo only |
| `bootstrap` | Komodo API | **box** |
| `reconcile` | Komodo API | **box** |
| `host-ports` | box over SSH | **box**, dry-run by default already |

What has to be decided:

- **The uniform shape.** `host-ports` took `*args` + `--apply` and prints the
  exact remote command it would run. Whether that is the convention, or
  something else (a `-y` flag, a confirm prompt, a `plan`/`apply` recipe pair),
  and whether the flag name is `--apply` everywhere.
- **What a dry run *is* for each recipe.** This is the hard half, and it is not
  uniform. `host-ports` can diff cheaply because the desired state is a file.
  **`reconcile` has a native answer waiting**: [08](08-deploy-homepage.md)
  established that a ResourceSync *applies nothing by itself* — `RunSync` only
  reports pending changes, and `BatchDeployStackIfChanged` is the half that
  deploys. So a dry run is plausibly "report pending, deploy nothing", which is
  a genuinely useful thing to have anyway. `bootstrap` creates a resource that
  either exists or does not, so its dry run may just be a existence check.
- **Whether interactive recipes are carved out.** `secret` opens an editor on a
  repo file and never touches the box; a dry run may be meaningless there. If
  so, say so explicitly rather than leaving it ambiguous.
- **Where the convention is written down** so later tickets inherit it. The
  natural home is [07](07-repo-layout-and-conventions.md)'s live artifact —
  [docs/repo-layout.md](../../../docs/repo-layout.md) or
  [docs/adding-a-service.md](../../../docs/adding-a-service.md) — not this map.
- **Whether `just --list` should show the danger.** The one-line comments are
  what a person reads before running something; a convention in the comment text
  is close to free.

**Timing.** This does not block [16](16-deploy-caddy.md), and should not — 16 is
the map's biggest remaining ticket. But 16 and the migrations
[21](21-migrate-arr-stacks.md)–[24](24-migrate-download-stack.md) will add
recipes, so the longer this sits the more there is to retrofit. Worth taking
early.

**Related**: [26](26-host-state-scope.md) asks what host state git owns; this
asks how any of it gets applied. They are separable — 27 is about the safety of
the mechanism regardless of what it manages.

**HITL**: a convention decision, so `/grilling`; the execution that follows is
small.

Blocks nothing. Nothing blocks it.

## Resolution (2026-08-03)

**The rule is not the one the ticket was written to ask for**, and the human
corrected it in the first minute:

> I want the `--apply` flag to be added primarily to items that run during
> initial bootstrap and box setup, reconcile should be safe by definition

The ticket's framing was *mutates the box → gate it*, which catches `reconcile`.
The rule that survives is:

> **`--apply` guards a recipe that changes the box in a way the reconcile loop
> would not.**

**The test is provenance, not blast radius** — did a committed file already say
to do this? `just reconcile` is a big act and stays **ungated**, because the
15-minute cron performs the identical Procedure whether anyone types it or not;
running it only makes the box arrive sooner at the state `main` already
describes. The decision was the merge, and [12](12-image-update-strategy.md)
already put the guard there with its four human-merge carve-outs. `bootstrap`
and `host-ports` are the opposite: nothing else will ever run them, so typing
them *is* the decision. This is worth stating plainly because it means **a
recipe with a huge blast radius is deliberately left unguarded** — `just
reconcile` against a bad `main` will happily wreck the box, and the answer to
that is to not merge it.

Landed as a `### Recipes` section in
[docs/repo-layout.md](../../../docs/repo-layout.md) — 07's live artifact, as
this ticket asked — plus a *Recipe* entry in
[CONTEXT.md](../../../CONTEXT.md)'s glossary, which is where the word is fixed.

### What a gated recipe is

- `*args` in the justfile, passed through; **the script parses the flag**, not
  `just`
- the flag is `--apply` and there is no other
- default is a dry run reporting **an overview** of what would happen. The
  ticket's fifth bullet proposed adopting `host-ports`' *print the exact remote
  command* as a hard requirement; the human **declined** — "a brief overview of
  what would happen should be sufficient". Right call: it was the one clause that
  constrained how a script must be written, and it does not survive contact with
  `bootstrap`, where "the exact thing" is a JSON body to an HTTP endpoint.
- exits 0 with a plain "nothing to do"
- its `just --list` comment ends `-- pass --apply to commit`, so gating is
  visible at the moment of choosing

**No confirmation prompt, anywhere.** A prompt cannot run unattended and trains
a reflex; a dry run makes you read output and retype, which is a real pause.

**`secret` is explicitly not gated** — it edits a repo file, and the repo is not
the box. The ticket asked for that to be said out loud rather than left
ambiguous, and the docs now say it.

### What changed in the repo

`bootstrap` is now dry-run by default
([scripts/komodo.sh](../../../scripts/komodo.sh)) and `just bootstrap` takes
`*args`. Its dry run is an **existence check only** — option 1 of three put to
the human, who took it: *"I mostly care about 1, we should avoid bootstrapping
for no reason."* The richer option (Komodo's pending-changes summary) was
declined, and rightly: the question you are actually asking at step 8 of a
rebuild is *is there anything to bootstrap*, and the danger is never the fresh
box where nothing exists, but a later run against a live Komodo.

**`--apply` is behaviour-identical to the old recipe** — create-if-absent then
`RunSync`, unchanged. Only the default moved.

`host-ports` needed no code change; its comment was aligned to the shared
wording. `reconcile`'s comment now says **"Ungated"** — belt-and-braces against
the convention's own claim that a missing marker means ungated, because
`reconcile` is the one recipe a reader would expect to be guarded.

Verified against the live box, all three dry-run branches, `just lint` green:

- sync present → `sync 'unraid-ops' exists`, exit 0, nothing written
- sync absent (name temporarily changed, reverted immediately — a dry run cannot
  write) → `* sync '…' is missing -- would be created`, exit 0
- bad flag → usage, exit 1

`just --list` now shows `-- pass --apply to commit` on exactly `bootstrap` and
`host-ports`.

### A DRY question, answered by the dependency order

The human asked whether `bootstrap` should just call `reconcile`. **It cannot,
and the reason is structural**: `reconcile` runs a Komodo *Procedure* named
`reconcile`, which is declared in [komodo/procedures.toml](../../../komodo/procedures.toml)
— inside the sync's `resource_path`. So the Procedure is **created by** the very
`RunSync` that bootstrap performs, and on a fresh box `just reconcile` would
fail against a Procedure that does not exist yet. Second reason even on a live
box: reconcile's stage two is `BatchDeployStackIfChanged`, so the chain would
make bootstrap *deploy containers*. And there is no duplication to collapse —
both commands already share `login`/`api` in one file.

### What went to a new ticket

Asked where the convention should live, the human pushed past the question:
`docs/repo-layout.md` is ~440 lines with 17 `###` sections, unindexed, and
"layout" no longer describes it. That, plus a `CLAUDE.md` — because **nothing in
this repo is auto-loaded**, and the instruction to read the three docs currently
lives only in the map's Notes, which are `.scratch/` and vanish when the map
closes — is now [28](28-navigable-standing-docs.md). Split deliberately: a docs
refactor would have swallowed a safety rule that [16](16-deploy-caddy.md) and the
migrations are about to inherit, and 28 found **74 references across 25 files**
to the old filename, 22 of them in closed tickets. `### Recipes` moves with
everything else when 28 runs.

No new secrets. Nothing on the box changed.
