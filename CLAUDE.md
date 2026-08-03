# CLAUDE.md

GitOps for Docker on an Unraid box. Container definitions live here; Komodo
reconciles them onto the host on a 15-minute poll.

## Read before you work

| file | for |
|---|---|
| [CONTEXT.md](CONTEXT.md) | the words this repo uses, and the ones it doesn't |
| [docs/conventions.md](docs/conventions.md) | the standing rules — it has an index; read the section |
| [docs/adding-a-service.md](docs/adding-a-service.md) | before adding or adopting any service |

Every rule's reasoning is in the ticket it links, under
[.scratch/unraid-gitops/](.scratch/unraid-gitops/). The
[map](.scratch/unraid-gitops/map.md) is what is decided and what is left.

## Expensive to break by accident

- **The `BatchDeployStackIfChanged` pattern is an explicit list of Stack names.
  Never `*`** — a wildcard recreates `plex` and the gluetun/qbittorrent pair
  unattended.
- **Every image is `version@digest`.** No exceptions.
- **Nothing is built on the box.** If something must be built, GitHub Actions →
  GHCR.
- **Nothing faces the internet without `x-published: true`.** `caddy.import:
  internal` is the default and `just lint` enforces the choice.
- **`--apply` gates any recipe that changes the box in a way the reconcile loop
  would not.** `reconcile` is deliberately ungated.
- **Never bind `/etc/localtime`** — runc under Docker 29.5.3 refuses it and the
  container will not start. `TZ` in `common.env` does the job.
- **`just secret <stack>`, never `sops --encrypt`** on a path outside a Stack
  directory: it finds no creation rule.
- **Do not POST to Komodo's API ad hoc.** New operations go in
  [scripts/komodo.sh](scripts/komodo.sh) behind a recipe.

## The box

`root@tower` over tailscale, key-based SSH. Its only other remote path is the
Unraid Web UI on **port 8008**, and there is no out-of-band console — a lockout
is a multi-day outage. **State the rollback before any change touching port
80/443, docker networking, or tailscale.**

## Commands

`mise install` once, then `just` to list the recipes. `just lint` is the gate
every Stack must pass, and it runs in CI.
