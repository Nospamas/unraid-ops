# Reconcile mechanism: comparison and choice

Asset for [02 — Choose the reconcile mechanism](../issues/02-choose-reconcile-mechanism.md).
Researched 2026-08-01.

> **Researched against Komodo v1.18.0. Current is v2.3.1** (released
> 2026-07-31). The choice stands — every field this comparison rests on
> (`pre_deploy`, `project_name`, `additional_env_files`, `files_on_host`,
> ResourceSync, empty `git_account`) survives v2, and the database options are
> unchanged. What is stale is the install mechanics: **passkeys are gone**
> (Core and Periphery auto-generate a rotating keypair), **Periphery now dials
> Core** rather than the reverse, `:latest` is deprecated in favour of `:2`, and
> the Community Apps route is dropped in favour of one compose file. See
> [11](../issues/11-stand-up-komodo.md)'s findings.

## The choice

**Komodo**, running entirely as containers on the box: `komodo-core` +
a Mongo-compatible database + `komodo-periphery`.

**Portainer is removed** once adoption is verified. Its two stacks (`plex`, and
`gluetun`+`qbittorrent`) are adopted in place by Komodo, by compose project
name, without recreating them first.

## Why — the constraint that decided it

Ticket 01 established the hard one: **Unraid 7.3.2 / Docker 29.5.3 with no
compose implementation on the host**, no Compose Manager plugin, no User
Scripts plugin, and an OS that lives in RAM and rebuilds from `/boot` on every
boot. Any candidate must carry its own compose, inside a container.

Komodo does, provably. The Periphery image's dependency installer
([`bin/periphery/debian-deps.sh`](https://github.com/moghtech/komodo/blob/main/bin/periphery/debian-deps.sh))
ends with:

```sh
apt-get install -y docker-ce-cli docker-buildx-plugin docker-compose-plugin
```

plus `git` earlier in the same script. So the Periphery container ships the
docker CLI, the compose v2 plugin, and git; it talks to the host's daemon over
`/var/run/docker.sock`. Nothing is installed on the host, so nothing is lost on
reboot. There is also a **Komodo Periphery entry in Community Apps**, so the
install path is the ordinary unraid one.

That alone eliminates the two options that need host-side compose, and Dockge
eliminates itself on git. What Komodo then wins on over Portainer is a
different axis — see "Komodo vs Portainer" below.

## Candidates against the five criteria

### 1. Komodo — **chosen**

| Criterion | Verdict |
|---|---|
| Compose on host | **Not needed.** Periphery image bundles `docker-ce-cli` + `docker-compose-plugin` + `git`. |
| Adoption | **In place.** "Komodo matches projects by compose project name — if the running project name differs from the Stack name, set a custom `project_name`." The two Portainer stacks are adopted by name; the five dockerMan containers are recreated (safe — see "Adoption risk"). |
| Secrets at apply time | **Three routes.** `environment` written to a `.env` and passed as `--env-file`, with `[[KEY]]` interpolation from Komodo Variables; secrets in `core.config.toml` (never exposed by API); secrets in `periphery.config.toml` (never leave the box). Plus a **`pre_deploy` SystemCommand** hook — the only candidate with a real pre-apply hook, which is what keeps SOPS on the table for ticket 03. |
| Push vs poll | **Both, and poll works today.** Webhooks for push. For poll: ResourceSync — "The Komodo Core backend will poll the files for any updates" — plus a Procedure on a cron schedule running `BatchDeployStackIfChanged` with pattern `*`. No inbound port required. |
| Reboot survival | **Yes**, all three components are containers with restart policies; nothing on the host filesystem. |
| Drift | `DeployStackIfChanged` diffs the tracked files; a scheduled run re-applies. Stack state alerts on change (`send_alerts`, default true). |

**The clincher: Komodo's own configuration is git-owned.** ResourceSync declares
Stacks, Servers and Procedures as TOML in the repo and diffs them against
what exists. So "which stacks exist and how they are configured" is a file in
this repo, not rows clicked into a UI database. That is the difference between
GitOps and a UI that happens to read git.

**Costs, honestly:**

- **Three new containers** (Core, database, Periphery). Komodo supports MongoDB
  (recommended) or FerretDB-on-Postgres; Postgres and SQLite are *not* directly
  supported as of v1.18.0. This is the largest footprint of any candidate.
- **`PERIPHERY_ROOT_DIRECTORY` must be the same path inside and outside the
  container** for stack/repo path resolution to work — so the mount is
  `/mnt/user/appdata/komodo:/mnt/user/appdata/komodo`, identical on both sides,
  not the usual `:/etc/komodo`. Ticket 08 will hit this on day one.
- **SOPS is not free.** `pre_deploy` exists, but the Periphery image has no
  `sops` binary, so SOPS means a custom Periphery image or a decrypt sidecar.
  Handed to ticket 03 as a known cost, not a blocker.
- **Younger and single-maintainer** next to Portainer. Mitigated by the fact
  that what it manages is plain compose — the exit cost is low, because the
  compose files stay valid without it.

### 2. Portainer git stacks — runner-up, rejected

Genuinely close, and rejected on its merits rather than by incumbency. It
clears the hard constraint too: Portainer embeds a compose implementation, so
it needs nothing on the host, and it runs as a container so it survives reboot.
CE supports git stacks with **both** polling on an interval and webhooks, plus
a **force redeployment** setting that re-applies on schedule "overwriting any
changes that have been made in the local environment" — the best drift answer
of any candidate, better than Komodo's.

Rejected because:

- **The stack list is not in git.** Which stacks exist, which repo and branch
  each tracks, the poll interval, the env vars — all live in Portainer's own
  database. A box rebuild replays the repo *and* reconstructs Portainer by hand.
  Komodo's ResourceSync closes exactly this gap. Given the destination says a
  `git push` reconciles the box, the layer that decides what gets reconciled
  should not be the one layer held outside git.
- **No pre-apply hook.** Secrets reach a Portainer stack as stack env vars or a
  `.env`; there is no place to run `sops -d` before `compose up`. Choosing
  Portainer would effectively decide ticket 03 in advance, and decide it against
  the home-ops SOPS habit.

Both are real, and the second follows from the first. Not disqualifying on its
own — but with Komodo clearing the same bar and closing both gaps, there is no
argument left for Portainer beyond it already being here, which the ticket
explicitly ruled inadmissible.

### 3. Dockge — rejected

No native GitOps and no auto-update. Community workarounds exist (a sidecar that
polls the repo and pokes Dockge), which is a confession, not a feature. Fails
criterion 3 outright.

### 4. Unraid Compose Manager plugin — rejected

The original plugin is **deprecated** and no longer maintained; the successor
is Compose Manager Plus. Either way it is a UI over compose projects stored on
`/boot`, with **no git integration at all** — "pull" means `docker compose
pull` (images), not `git pull`. It would satisfy criterion 1 by installing the
compose CLI on the host and criterion 4 via the plugin mechanism, but there is
nothing to reconcile *from*. Fails criterion 3, which is the destination.

### 5. Plain `git pull` + `docker compose up -d` — rejected

Bitten hardest by the constraint, exactly as the ticket predicted, and by a
second one it did not: there is **no User Scripts plugin and no cron the box
offers**, so both the compose implementation *and* the thing that runs it on a
timer would have to be installed and made reboot-proof by hand. The honest
version of this option is "a container that holds git and compose and runs a
loop" — at which point you have written a worse Komodo. Rejected on maintenance
cost, not on principle.

## Adoption risk: why recreating containers is safe

Every in-scope service keeps its state in a **bind mount under
`/mnt/user/appdata`** (per ticket 01) — not in named or anonymous volumes.
Destroying and recreating a container therefore cannot lose data; the data was
never in the container. Adoption risk is configuration risk, not data risk:
getting the mounts, env and ports right in the translated compose file. That is
ticket 07's job, and ticket 08 proves the loop on homepage, which has no data
at all.

Two unraid-specific gotchas, for tickets 07 and 08:

- **Unraid's autostart list is keyed by container name**
  (`/var/lib/docker/unraid-autostart`). If compose creates a container with a
  name unraid still has on its autostart list, unraid and compose both try to
  start it. Autostart must be turned off in the Docker tab for each of the five
  dockerMan-managed containers as they are taken over, with `restart:
  unless-stopped` in compose replacing it.
- **Once compose owns a container, the Docker tab loses its Edit button** — no
  template, so unraid shows it as a foreign/orphan container. This is the
  expected end state given the map's Container scope note (no two-tier box).
  The template XML under `/boot/config/plugins/dockerMan/templates-user/`
  should be kept until translation is verified; it is ticket 07's raw material.

## Portainer's fate

1. Stand Komodo up alongside Portainer. Nothing moves.
2. Adopt `plex` and `gluetun`+`qbittorrent` by setting Komodo's `project_name`
   to the existing Portainer project names (`docker compose ls` on the box gives
   the exact names). Their compose files move from
   `/mnt/user/appdata/portainer/compose/` into this repo.
3. Migrate the five dockerMan containers per ticket 07.
4. **Remove the PortainerCE container** once every workload reconciles from the
   repo. Not kept as a read-only UI — Komodo has one, and a second tool that can
   also write is a drift source, not a viewer.

Portainer's appdata stays on disk until removal is confirmed good, then goes.

## Consequence for the rest of the map

**The box must be able to reach the repo.** Every candidate that survived needs
a git remote, and Komodo clones over HTTPS (it does not support SSH clone). The
map's deferred "Publishing to GitHub" is therefore no longer optional or
deferrable — it is a hard prerequisite for ticket 08. Graduated to a ticket.

Poll, not webhook, for now: a GitHub webhook needs an inbound path to the box,
which does not exist until ticket 05 settles remote access. Cron-scheduled
`BatchDeployStackIfChanged` satisfies "reconciles automatically" with no open
ports; the webhook can be added later as an optimisation.

## Sources

- [Komodo — Docker Compose](https://komo.do/docs/deploy/compose)
- [Komodo — Sync Resources](https://github.com/moghtech/komodo/blob/main/docsite/docs/automate/sync-resources.md)
- [Komodo — Procedures and Actions](https://github.com/moghtech/komodo/blob/main/docsite/docs/automate/procedures.md)
- [Komodo — Variables and Secrets](https://komo.do/docs/configuration/variables)
- [Komodo — Connect Servers](https://komo.do/docs/setup/connect-servers)
- [`bin/periphery/debian-deps.sh`](https://github.com/moghtech/komodo/blob/main/bin/periphery/debian-deps.sh) — the compose-in-image proof
- [`config/core.config.toml`](https://github.com/moghtech/komodo/blob/main/config/core.config.toml) — poll intervals, database options
- [`client/core/rs/src/entities/stack.rs`](https://github.com/moghtech/komodo/blob/main/client/core/rs/src/entities/stack.rs) — `pre_deploy`, `project_name`, `webhook_enabled`, `additional_env_files`
- [Komodo Periphery — Unraid Community Apps](https://ca.unraid.net/apps/komodo-periphery-07m34ot0zv5pg9)
- [Komodo Periphery on Unraid — discussion #530](https://github.com/moghtech/komodo/discussions/530)
- [Portainer — how automatic updates for stacks work](https://docs.portainer.io/faqs/troubleshooting/stacks-deployments-and-updates/how-do-automatic-updates-for-stacks-applications-work)
- [Portainer — add a new stack](https://docs.portainer.io/user/docker/stacks/add)
- [Unraid Compose Manager Plus (successor to the deprecated plugin)](https://forums.unraid.net/topic/197334-plugin-compose-manager-plus/)
- [Dockge — stack in git repo, discussion #36](https://github.com/louislam/dockge/discussions/36)
- [Unraid — managing and customizing containers](https://docs.unraid.net/unraid-os/using-unraid-to/run-docker-containers/managing-and-customizing-containers/)
