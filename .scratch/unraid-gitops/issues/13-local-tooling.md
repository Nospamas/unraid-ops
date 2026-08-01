# 13 — Decide the local tooling and task runner

Type: grilling
Status: open
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
