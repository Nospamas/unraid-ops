# 02 — Choose the reconcile mechanism

Type: research
Status: closed
Assignee: Nospamas
Resolved: 2026-08-01
Asset: [assets/02-reconcile-mechanism.md](../assets/02-reconcile-mechanism.md)

## Question

How does the unraid box get changes out of this repo and apply them?

**Incumbency is not evidence.** Ticket 01 found Portainer already on the box,
running a hand-made qbittorrent+gluetun stack. The human has ruled explicitly
that this must *not* weigh in Portainer's favour here — judge it on the five
criteria below like any other candidate, and be willing to conclude the stack
should move off it. What is being kept is qbittorrent and gluetun, not the thing
currently deploying them.

**Hard constraint from [01](01-inventory-running-containers.md): there is no
compose implementation on the box.** Unraid 7.3.2 ships Docker 29.5.3 with no
`docker compose` plugin, and neither the Compose Manager nor the User Scripts
plugin is installed. Every candidate must therefore either carry its own compose
implementation inside a container, or install one somewhere that survives a
reboot — unraid's OS lives in RAM and rebuilds from `/boot`. This bites the
"plain `git pull` + `docker compose up -d`" option hardest.

**Also settle Portainer's fate.** It currently runs two stacks (`plex`, and
`gluetun`+`qbittorrent`) from `/mnt/user/appdata/portainer/compose/`. Whatever
wins, say what happens to those two stacks and whether Portainer is removed,
kept as a read-only UI, or kept as the mechanism.

Compare, as a written asset in the repo:

- **Komodo** — purpose-built GitOps for Docker hosts, watches a repo, applies
  compose stacks, has a UI.
- **Dockge** — lighter compose manager, git support is thinner.
- **Portainer git stacks** — polls a repo and redeploys on change.
- **Unraid Compose Manager plugin** — native to the platform, weakest git story.
- **Plain `git pull` + `docker compose up -d`** driven by an unraid user script
  or systemd timer — no extra platform, you own the glue.

Judge each against the constraints this map has already fixed:

1. **Adoption without data loss** — can it take over containers that unraid's
   Docker tab currently manages, keeping their appdata mounts intact? What
   happens to the unraid UI's view of a container once compose owns it?
2. **Secret decryption at apply time** — the secrets decision
   (ticket 03) depends on this. Does the tool support an encrypted-at-rest
   secrets file, a pre-apply hook, or only plain `.env`?
3. **Push vs poll** — does a `git push` trigger it (webhook), or does it poll on
   an interval? The destination says "reconciles automatically"; a 5-minute poll
   satisfies that, a manual button does not.
4. **Survives an unraid reboot** — unraid's OS lives in RAM and rebuilds from
   `/boot` on boot. Anything installed outside a Docker container or a plugin
   will not persist. Confirm how each option survives.
5. **Drift behaviour** — what it does when a container is changed by hand.

The answer names the choice and the reason, not a survey.

## Resolution

**Komodo**, running entirely as containers on the box: `komodo-core` + a
Mongo-compatible database + `komodo-periphery`. Full comparison in
[assets/02-reconcile-mechanism.md](../assets/02-reconcile-mechanism.md).

**What decided it.** The hard constraint — no compose on the host, and an OS
that rebuilds from `/boot` every reboot — is cleared by Komodo *and* Portainer,
both of which carry compose inside a container. Komodo's Periphery image
provably does: its dependency script installs `docker-ce-cli`,
`docker-compose-plugin` and `git`, and it drives the host daemon over
`/var/run/docker.sock`. There is a Periphery entry in Community Apps, so the
install is the ordinary unraid one.

Against Portainer — a close runner-up, judged on merit, not incumbency —
Komodo wins on two things:

1. **Komodo's own config is git-owned.** ResourceSync declares Stacks, Servers
   and Procedures as TOML in this repo and diffs them against reality. In
   Portainer, the stack list, repo, branch and env vars live in Portainer's
   database, so a box rebuild replays the repo *and* rebuilds Portainer by hand.
   The layer deciding *what* gets reconciled should not be the one layer outside
   git.
2. **A real pre-apply hook.** Komodo Stacks have a `pre_deploy` SystemCommand.
   Portainer has nowhere to run `sops -d` before `compose up`, so choosing it
   would have silently decided [03](03-secrets-handling.md) against SOPS.

Portainer's own drift story is actually *better* (force-redeploy on interval,
overwriting hand edits); it lost on the two above.

Rejected: **Dockge** — no native GitOps or auto-update, the workarounds are
sidecars that poll the repo for it. **Compose Manager plugin** — original is
deprecated, successor is Compose Manager Plus, and neither has any git
integration; "pull" means images, not commits. **Plain `git pull` + `compose
up`** — bitten hardest, and by a second constraint the ticket did not list:
with no User Scripts plugin there is no timer either, so the compose
implementation *and* its scheduler both need making reboot-proof by hand. The
honest version of that option is a container holding git and compose on a loop,
i.e. a worse Komodo.

**Facts later tickets lean on:**

- **Reconcile is poll, not webhook, for now.** A GitHub webhook needs an inbound
  path that will not exist until [05](05-remote-access.md). Instead: a Komodo
  Procedure on a cron schedule running `BatchDeployStackIfChanged` with pattern
  `*`, plus Core's own polling of ResourceSync files. No open ports. Webhook is
  a later optimisation, not a requirement.
- **The box must reach the repo.** Komodo clones over HTTPS and does **not**
  support SSH clone. Publishing to a remote is therefore a hard prerequisite for
  [08](08-deploy-homepage.md), not a deferred nicety — graduated out of the fog
  as [10](10-publish-repo-to-remote.md).
- **Secrets, for [03](03-secrets-handling.md):** three native routes —
  `environment` written to a `.env` and passed as `--env-file` with `[[KEY]]`
  interpolation from Komodo Variables; secrets in `core.config.toml`; secrets in
  `periphery.config.toml` (never leave the box). SOPS stays viable via
  `pre_deploy`, **at a cost**: the Periphery image has no `sops` binary, so it
  means a custom image or a decrypt sidecar. Note the native routes all store
  values in Komodo's database or in TOML on the box — off-git either way.
- **Adoption is configuration risk, not data risk.** All appdata is bind-mounted
  under `/mnt/user/appdata`, never in named volumes, so recreating a container
  cannot lose data.
- **`PERIPHERY_ROOT_DIRECTORY` must be an identical path inside and outside the
  container** for stack path resolution — mount
  `/mnt/user/appdata/komodo:/mnt/user/appdata/komodo`, not the usual
  `:/etc/komodo`. [08](08-deploy-homepage.md) hits this on day one.
- **Two unraid gotchas for [07](07-repo-layout-and-conventions.md):** unraid's
  autostart list is keyed by *container name*, so autostart must be switched off
  in the Docker tab for each container as compose takes it over, with `restart:
  unless-stopped` in compose replacing it — otherwise unraid and compose race.
  And once compose owns a container the Docker tab loses its Edit button and
  shows it as foreign; keep the template XML until translation is verified.
- **Komodo needs MongoDB or FerretDB-on-Postgres.** Postgres and SQLite are not
  directly supported as of v1.18.0. Three new containers is the largest
  footprint of any candidate — the accepted cost of the two wins above.

**Portainer's fate: removed.** Stand Komodo up alongside it; adopt the `plex`
and `gluetun`+`qbittorrent` stacks in place by setting Komodo's `project_name`
to the existing Portainer project names (`docker compose ls` gives them), moving
their compose files out of `/mnt/user/appdata/portainer/compose/` and into this
repo; migrate the five dockerMan containers per 07; then delete the PortainerCE
container. Not kept as a read-only UI — a second tool that can also write is a
drift source, and Komodo has a UI.
