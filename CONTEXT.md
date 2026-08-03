# unraid-ops

GitOps for Docker on an Unraid box: container definitions live in this repo, and
Komodo reconciles them onto the host. This file is the glossary — the words this
repo uses and the ones it deliberately doesn't. The rules are in
[docs/conventions.md](docs/conventions.md); the routine is in
[docs/adding-a-service.md](docs/adding-a-service.md).

## The unit of work

**Stack**:
One directory under `stacks/`, holding a compose file and the Komodo TOML that
declares it. The repo's atom. Usually one container; occasionally a set that must
be created and destroyed together.
_Avoid_: app, service (as a name for the directory), workload, module

**Service**:
A single container inside a Stack — a compose `services:` entry. Most Stacks
have exactly one, so the words nearly coincide; `download` is where they come
apart.
_Avoid_: app, container (when talking about the definition rather than the
running thing)

**Adopting**:
Bringing a container that already runs on the box under this repo's control
without losing its appdata, history or settings. An adopted Stack must produce a
container that the existing appdata still fits.
_Avoid_: migrating, importing, onboarding

## Configuration

**Shared config**:
The values every Stack needs — PUID/PGID/UMASK/TZ, the appdata root, the media
root. Lives once in `common.env` at the repo root and reaches each Stack through
its `additional_env_files`.
_Avoid_: globals, defaults, base config

**Secret**:
A value that must not sit in git in the clear. Encrypted per Stack as
`secrets.sops.env`, decrypted on the box to `secrets.env` by that Stack's
`pre_deploy`.
_Avoid_: credential, env var (a secret is a kind of env var, not a synonym)

**Appdata**:
The per-service state directory on the box, under `/mnt/user/appdata`. Git never
owns it — it is the boundary between what this repo reconciles and what a
service's own UI edits. Homepage is the sole exception, because its config is
files rather than a database.
_Avoid_: config volume, data dir, state

**Service settings**:
What lives in appdata and is edited in a service's own web UI — sonarr's
indexers, quality profiles, root folders. Explicitly not reconciled. A change
here is not a `git push`.
_Avoid_: config (which in this repo means the git-owned definition)

## Reconciliation

**Reconcile**:
Komodo cloning this repo onto the box and bringing the running containers into
line with what it finds. Polled on a schedule, not triggered by a webhook.
_Avoid_: sync, deploy (a deploy is one Stack; a reconcile is the whole loop),
apply

**ResourceSync**:
Komodo's own git-owned configuration — the TOML that declares which Stacks,
Servers and Procedures exist. Komodo's term; kept as-is.

**Bootstrap**:
What has to exist on the box before a reconcile can happen at all: Komodo's own
four containers, the age key, the sops binary. Held in `bootstrap/`, run by hand,
and never reconciled — Komodo cannot deploy itself.
_Avoid_: install, setup, provisioning

**Recipe**:
One entry in the `justfile`. A recipe is **gated** when it changes the box in a
way the reconcile loop would not — it then takes `--apply` and does nothing
without it, and says so in its `just --list` comment. `reconcile` is ungated
because the cron runs it anyway.
_Avoid_: task, command, script (`scripts/` holds what a recipe calls)

## Exposure

**Fronted**:
Reachable through Caddy at a `*.rbrb.in` hostname. A Stack becomes fronted by
carrying `caddy` labels, and every fronted Service is `internal` unless it says
otherwise.
_Avoid_: proxied, exposed (which reads as internet-facing), routed

**Internal**:
Admitting only the LAN (`192.168.1.0/24`) and the tailnet (`100.64.0.0/10`). The
default for everything, applied by a `caddy.import: internal` label resolving to
a snippet in Caddy's base Caddyfile.
_Avoid_: private, LAN-only (the tailnet is not the LAN), restricted

**Published**:
Deliberately reachable from the internet. Marked by an `x-published: true` key on
the Service, which the repo check requires as the only alternative to `internal`.
Nothing is published today; the word exists so that publishing can never be an
accident.
_Avoid_: public, exposed, open

**The shared network**:
`shared` — the one external docker bridge every container joins. Carries both
Caddy's discovery traffic and the *arr → gluetun download-client traffic.
External in every Stack, because Komodo runs each Stack as its own compose
project.
_Avoid_: proxy network, the caddy network, frontend
