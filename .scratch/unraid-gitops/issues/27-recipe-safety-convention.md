# 27 — Make every mutating `just` recipe dry-run by default

Type: grilling
Status: open

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
