---
id: "13"
title: Decide the local tooling and task runner
type: grilling
status: closed
description: >
  `just`, not go-task — the human's call against the recommendation, so there
  is no second runner. Landed the whole local toolchain: `.mise.toml`, the
  justfile, `.sops.yaml`, `.renovaterc.json5` and CI. Biggest find: 03's age
  keypair had never been generated, silently blocking three tickets.
touches: [justfile, .mise.toml, .renovaterc.json5, .github/workflows/lint.yaml]
---

# 13 — Decide the local tooling and task runner

Resolved: 2026-08-02
Blocked by: 03

## Question

What does a human need installed to work on this repo, how is that pinned, and
what are the common commands?

Raised by the human while resolving [03](03-secrets-handling.md): the map had no
home for local developer tooling at all. 03 made it specifiable by settling that
secrets are SOPS + age, which fixes *what* has to be pinned and *which* commands
have to exist.

The stated intent is to **match how `~/home-ops` operates** — mise for tooling,
with updates driven by Renovate, plus a task runner for common commands. That
narrows this to a set of concrete choices rather than an open field.

**What home-ops actually does**, as the reference for taste:

- `.mise.toml` pins every tool by exact version through `aqua:` and `pipx:`
  backends — including `aqua:getsops/sops` and `aqua:FiloSottile/age`, the two
  this repo definitely needs. `gh` is the sole `latest`.
- `[env]` in the same file exports `SOPS_AGE_KEY_FILE = "{{config_root}}/age.key"`,
  so decryption works from anywhere in the repo with no shell setup.
- `Taskfile.yaml` (go-task) at the root, `default: task --list`, `includes:`
  pointing at a `.taskfiles/` directory of per-area taskfiles, and tasks
  guarded by `preconditions:`.

Settle:

- **Which task runner.** The human raised `just` as an alternative to Taskfiles.
  home-ops uses **go-task**, which is the taste-matching default and means one
  syntax across both repos — but `just` is markedly simpler, and this repo will
  have far fewer tasks than a Talos/Flux cluster does, so the argument that go-task
  earns its complexity here is weaker. Decide on merit, not only on symmetry.
- **What the tasks actually are.** Candidates: edit/re-encrypt a secret, verify
  every `*.sops.env` decrypts, lint compose files, trigger a Komodo reconcile
  rather than waiting for the poll. Some of these need [07](07-repo-layout-and-conventions.md)'s
  layout before they can be written — decide which are worth having now and
  which wait.
- **The `age.key` ergonomics.** 03 put the private key on the box and in
  KeePassXC. This ticket decides where it sits *locally* and how `SOPS_AGE_KEY_FILE`
  finds it — home-ops uses a gitignored `age.key` at the repo root, which is the
  obvious lift, but confirm rather than assume. Whatever is chosen must be
  gitignored; home-ops' `.gitignore` is the reference.
- **Renovate's scope here.** The human asked for Renovate to keep mise's pins
  fresh. Note the seam: this ticket covers Renovate for the **mise toolchain**;
  [12](12-image-update-strategy.md) covers Renovate for **container image tags**.
  They will share one `renovate.json` but are different datasources and different
  decisions — whoever lands second extends the config rather than writing it.
- **Whether a `.mise.toml` `[env]` block replaces a root `.env`** for the shared
  PUID/PGID/TZ trio, which [07](07-repo-layout-and-conventions.md) is otherwise
  weighing. If mise exports them for local tooling, 07 should know before it
  picks a different mechanism.

**Not blocked by [10](10-publish-repo-to-remote.md)**, though it touches it:
writing `renovate.json` and pinning tools needs no remote. Only *running* the
Renovate bot does, so enablement waits on 10 while the decision does not.

The answer states the tool list, the runner, the task inventory, and how
Renovate is scoped between this ticket and 12.

## Answered in part by [07](07-repo-layout-and-conventions.md)

- **The `.mise.toml` `[env]` question is closed: no.** mise runs on the laptop
  and never on the box, so it cannot be where compose values live. 07 put the
  shared trio in `common.env`, read by Komodo. `[env]` here stays scoped to the
  human's own tooling (`SOPS_AGE_KEY_FILE` and friends), exactly as home-ops
  uses it.
- **One task is now required rather than optional:** `task lint` must run
  `scripts/check-exposure.sh`, which asserts every fronted Service carries either
  `caddy.import: internal` or an explicit `x-published: true`. 07 chose an
  enforced check over an honour-system checklist, and this ticket owns where it
  is wired in. It needs a YAML reader — `yq` is already in the home-ops pin list.
- The layout the other candidate tasks were waiting on now exists: see
  [docs/conventions.md](../../../docs/conventions.md).

## Resolution

**`just`, not go-task.** The ticket framed this as simplicity vs symmetry with
`~/home-ops`, and the recommendation put to the human was go-task — on the
argument that go-task's complexity lives in the `includes:` + `.taskfiles/`
machinery a Talos/Flux cluster needs and this repo would never touch, so a flat
five-recipe Taskfile costs about what a justfile costs while keeping one syntax
across both repos. **The human took `just` anyway**, and go-task is therefore
**not pinned at all** — there is no second runner in this repo, and no reason to
add one. `just`'s positional parameters are what the daily command
(`just secret <stack>`) reads like, which was the one place the two tools were
not equivalent.

Scope was widened mid-ticket by a standing instruction from the human: *get
everything for general repo tooling setup into this issue as much as we can.*
That is why this ticket lands housekeeping dotfiles and a CI workflow rather than
only a runner and a tool list.

### What is now in the repo

| File | What it holds |
| --- | --- |
| [.mise.toml](../../../.mise.toml) | eight pinned tools + `SOPS_AGE_KEY_FILE` |
| [justfile](../../../justfile) | `default`, `secret <stack>`, `lint`, `verify-secrets` |
| [scripts/check-exposure.sh](../../../scripts/check-exposure.sh) | 07's default-deny check, written not just wired |
| [.sops.yaml](../../../.sops.yaml) | the one creation rule, with a real recipient |
| [.renovaterc.json5](../../../.renovaterc.json5) | mise + github-actions managers |
| [.github/workflows/lint.yaml](../../../.github/workflows/lint.yaml) | `just lint` on push and PR |
| [.shellcheckrc](../../../.shellcheckrc) [.editorconfig](../../../.editorconfig) [.gitattributes](../../../.gitattributes) | lifted from home-ops |
| [README.md](../../../README.md) | `mise install`, `just`, the command table |

### The tool list

All `aqua:` backends at exact versions, `gh` the sole `latest` — the home-ops
convention, and Renovate keeps them fresh:

`just 1.57.0` · `age 1.3.1` · `sops 3.13.3` · `hadolint 2.15.1` · `jq 1.8.2` ·
`shellcheck 0.11.0` · `yq 4.53.3` · `gh latest`

**Not pinned, deliberately.** Docker — 29.2.1 is system-installed, mise cannot
pin a daemon, and `compose` is its plugin. Renovate itself — local dry-runs are
[12](12-image-update-strategy.md)'s call if it ever wants them.

`mise install` was run and all eight resolve on the workstation. `mise` is
already activated in the human's zsh (`~/.zshrc:105`), so `[env]` applies on
`cd` and not only inside recipes.

### The age keypair existed nowhere, and now exists

The largest thing this ticket found. [03](03-secrets-handling.md) decided *a
fresh age keypair for this repo* in three places (box, KeePassXC, laptop) and
[07](07-repo-layout-and-conventions.md) decided `.sops.yaml`'s shape — but
**neither generated the key**, so `.sops.yaml` could not be written, and every
downstream secret-bearing ticket ([08](08-deploy-homepage.md)'s *arr API keys,
[14](14-cloudflare-zone-and-token.md)'s Cloudflare token, `download`'s WireGuard
key) was silently blocked on a step no ticket owned.

13 took it, because `age-keygen` is a pure-laptop act on a tool this ticket was
pinning anyway. Generating it on the box instead was considered and rejected: it
puts the private key in Unraid Web UI scrollback, and the key has to reach the
laptop and KeePassXC regardless.

**Recipient: `age1pj9c9wur8s7h7ynfh0pqxwvkd70hzvq92hvds4t5w0xfa5p83ggqfx5k25`**,
committed in [.sops.yaml](../../../.sops.yaml). The private key is at `age.key`
in the repo root, mode 600, gitignored (`git check-ignore` confirms).

**Round-trip verified end to end**: `just secret <stack>` on a non-existent file
opened an editor, wrote back ciphertext with the right recipient,
`just verify-secrets` passed, and `sops --decrypt` returned the plaintext.

### `scripts/check-exposure.sh` — written here, and it has teeth

07 said this ticket "owns where it is wired in". Wiring in a script that does not
exist is not wiring, so 13 wrote it. Two things came out of building it that the
map should not lose:

- **The first version passed silently on files it could not parse.** `yq` ran
  inside a process substitution, so its failure never reached `set -e` and the
  script printed `exposure ok` over fixtures that should have failed. A
  default-deny check that fails open is worse than no check. `yq` now runs into a
  variable and a parse error is a `FAIL`.
- **Compose labels have two forms** — the `key: value` map this repo writes, and
  a `- key=value` list. Reading only the first meant the check could be
  sidestepped by reformatting. Both are normalised now.
- **Declaring both `caddy.import: internal` and `x-published: true` is a
  failure**, not a precedence puzzle. 07 did not say; the intent is unreadable,
  so it fails.

Verified against seven fixtures — map form, list form, missing declaration, both
declarations, not fronted, published, and unparseable — plus the empty-`stacks/`
case, which passes. `shellcheck` is clean.

### Renovate and CI

`.renovaterc.json5`, not `renovate.json` — the home-ops filename, which buys
comments and trailing commas. Scoped to the **mise** and **github-actions**
managers only. [12](12-image-update-strategy.md) extends this file with the
docker/Dockerfile managers rather than inheriting an image policy guessed here;
the seam the two tickets agreed is unchanged.

**The Renovate App does not need installing.** The human corrected the plan here:
it is already installed on the `Nospamas` account for `home-ops`, so this repo
joins an existing installation — *Configure → Repository access → add
`unraid-ops`*. No repo file, no new credential.

CI is `.github/workflows/lint.yaml`, running `just lint` on push to `main` and on
every PR, free per [10](10-publish-repo-to-remote.md) because the repo is public.
**It touches no secrets** — check-exposure reads YAML and `docker compose config`
reads `common.env` — so the age key never goes near GitHub. Actions are pinned by
commit digest with the version in a trailing comment, matching the image-pinning
habit 07 chose, and `helpers:pinGitHubActionDigests` keeps them that way.

### Two defects found in 07's docs, both amended

The map says to amend the doc and say so, rather than deciding in the moment:

- **[docs/conventions.md](../../../docs/conventions.md)** named `Taskfile.yaml`
  and `renovate.json` in its tree. Corrected to `justfile` and
  `.renovaterc.json5`, with `.mise.toml` and `.github/workflows/` added, and the
  default-deny section updated to describe what the script actually enforces.
- **[docs/adding-a-service.md](../../../docs/adding-a-service.md)** step 4 said
  "never write plaintext into the repo" and then gave a command that encrypts an
  existing plaintext file — and, tested, that command **fails anyway**: SOPS
  matches creation rules against the *input* path, so encrypting from anywhere
  outside the Stack directory reports `no matching creation rules found`. Step 4
  is now `just secret <name>`, which never materialises plaintext. Step 8's
  `task lint` became `just lint` plus `just verify-secrets`.

### Declined

- **A `reconcile` recipe** triggering a Komodo deploy from the laptop. It needs a
  Komodo API key and Core URL locally; that key unlocks deploys on the box, so it
  cannot live in a public repo and would become a *second* KeePassXC-managed
  laptop secret — minted to avoid waiting for a poll cycle that Komodo's own web
  UI already short-circuits with a button. Cheap to add later if the wait annoys.
- **go-task**, on the human's call. See above.

### Hand-offs — all three done, 2026-08-02

1. **Renovate App repository access — done.** The dashboard issue proves it:
   [#1](https://github.com/Nospamas/unraid-ops/issues/1), opened 08:40Z by
   `brotherreno[bot]`. It detects both managers, and the actions parse in the
   `version@digest` form. It lists **seven** mise tools, not eight — `gh =
   "latest"` has no version to track, which is inherent to a floating pin rather
   than a config fault. Nothing to bump today, since everything was pinned to
   latest hours earlier.
2. **`age.key` filed in KeePassXC — done.**
3. **Key placed on the box — done**, `/mnt/user/appdata/komodo/age.key`, 189
   bytes matching the laptop copy byte-for-byte, mode `0600 root`. It took two
   attempts: the first transfer created the file but not its contents, so the
   check that caught it — `grep public` against the file, which needs no tools
   on the box and proves the key is the *right* one, not merely non-empty — is
   worth reusing on any future box rebuild.

**Still unproven**: nothing has decrypted with the box copy. `just verify-secrets`
exercises the laptop key only; the box key is untested until Periphery uses it,
which [11](11-stand-up-komodo.md) carries.

**Also observed while placing it**: `/mnt/user/appdata/komodo` and
`/mnt/user/appdata` are both mode **777**. Recorded on
[19](19-secret-hygiene-on-the-box.md) — it is the first look at the boundary 03
said it relied on, and it is not there.

### Facts later tickets lean on

- The age recipient is real and committed, so **any ticket may now write a
  `secrets.sops.env`** — use `just secret <stack>`, never `sops --encrypt` on a
  path outside the Stack directory.
- **`just lint` is the gate**, and it runs in CI. A Stack that adds a `caddy:`
  label without `caddy.import: internal` fails the build on the remote, not only
  on the laptop.
- The **mise/github-actions half of `.renovaterc.json5` is written**, and
  **Renovate is live and reading it** ([#1](https://github.com/Nospamas/unraid-ops/issues/1));
  [12](12-image-update-strategy.md) extends rather than rewrites.
- **No new secrets** live in the repo. The one new *asset* is `age.key`, which is
  03's root secret finally instantiated, not an addition to the secret set.
