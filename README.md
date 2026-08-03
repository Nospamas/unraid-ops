# unraid-ops

GitOps for the unraid box: container definitions in git, reconciled onto the host.

## Working on this repo

```bash
mise install          # every tool this repo needs, pinned in .mise.toml
just                  # list the commands
```

`mise` also exports `SOPS_AGE_KEY_FILE`, so `sops` finds the key with no shell
setup. Restore `age.key` to the repo root from KeePassXC on a fresh checkout — it
is gitignored, and nothing that touches secrets works without it.

`just --list` is the full set. A recipe whose comment ends `-- pass --apply to
commit` changes the box and does nothing without that flag. `just lint` also runs
in CI on every push and pull request.

## Where things are

- [CLAUDE.md](CLAUDE.md) — the rules that are expensive to break by accident
- [CONTEXT.md](CONTEXT.md) — the words this repo uses
- [docs/conventions.md](docs/conventions.md) — the standing rules, indexed
- [docs/adding-a-service.md](docs/adding-a-service.md) — the routine

Wayfinder map: `.scratch/unraid-gitops/map.md`
