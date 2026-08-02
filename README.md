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

| Command | What it does |
| --- | --- |
| `just lint` | exposure, compose files, shell scripts, Dockerfiles |
| `just secret <stack>` | edit a Stack's encrypted secrets |
| `just verify-secrets` | confirm every `*.sops.env` still decrypts |

`just lint` also runs in CI on every push and pull request.

## Where things are

- [CONTEXT.md](CONTEXT.md) — the words this repo uses
- [docs/repo-layout.md](docs/repo-layout.md) — the tree and its conventions
- [docs/adding-a-service.md](docs/adding-a-service.md) — the routine

Wayfinder map: `.scratch/unraid-gitops/map.md`
