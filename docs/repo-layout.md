# Repo layout

Decided by [ticket 07](../.scratch/unraid-gitops/issues/07-repo-layout-and-conventions.md).
Vocabulary is in [CONTEXT.md](../CONTEXT.md); the routine for adding a service is
in [adding-a-service.md](adding-a-service.md).

## The tree

```
common.env                  shared config, one copy, read by every Stack
.sops.yaml                  one creation rule: *.sops.env → the age recipient
.gitignore                  secrets.env, age.key
.mise.toml                  pinned local tools + SOPS_AGE_KEY_FILE
justfile                    local commands
.renovaterc.json5           mise pins and image bumps
CONTEXT.md                  glossary

.github/workflows/
  lint.yaml                 just lint, on push and PR

bootstrap/
  compose.yaml              komodo-core, ferretdb, postgres, periphery
  compose.env               non-secret config
  secrets.sops.env          Komodo's DB creds, JWT secret, initial admin
  README.md                 what to run by hand, in what order

komodo/
  sync.toml                 the ResourceSync + the Server
  procedures.toml           cron BatchDeployStackIfChanged

stacks/
  caddy/
    komodo.toml             [[stack]]
    compose.yaml
    Caddyfile               global options + the (internal) snippet
    secrets.sops.env        CF_API_TOKEN
  coredns/
    komodo.toml
    compose.yaml
    Corefile
  homepage/
    komodo.toml
    compose.yaml
    config/                 git owns these outright — they are files, not a db
      the full homepage skeleton: settings services widgets bookmarks
      docker kubernetes proxmox custom.css custom.js
    secrets.sops.env        the *arr API keys + the plex token
  dockerproxy/              read-only docker API, so homepage need not be root
    komodo.toml
    compose.yaml
  download/                 gluetun + qbittorrent, one namespace, one Stack
    komodo.toml
    compose.yaml
    secrets.sops.env        the NordVPN WireGuard key
  sonarr/ radarr/ prowlarr/ lazylibrarian/
    komodo.toml
    compose.yaml
  plex/
  calibre/

scripts/
  check-exposure.sh         every fronted Service is internal or x-published
  komodo.sh                 `just bootstrap` and `just reconcile` against Core's API
```

Twelve Stacks, thirteen containers. `bootstrap/` is the exception that proves the
rule: it is in git so a rebuild starts from a file rather than from memory, but
nothing reconciles it — Komodo cannot deploy the containers it runs inside.

**`bootstrap/` never gets a `komodo.toml`, and this is not an oversight to
tidy up.** Komodo Core *can* redeploy itself — Periphery does the work — but
Periphery cannot redeploy itself, and upstream requires the two match versions.
So the half that could automate is chained to the half that cannot. Bootstrap is
deliberately the one hand-updated thing on the box: Renovate raises the bump, a
human merges it, and a human applies it over SSH
([ticket 12](../.scratch/unraid-gitops/issues/12-image-update-strategy.md)).

That exception reaches the secrets convention too. `bootstrap/secrets.sops.env`
follows the same creation rule as every Stack's, but it is decrypted **by hand**
during bootstrap rather than by a `pre_deploy`, because the thing that runs
`pre_deploy` is what is being installed. `just secret bootstrap` edits it;
[bootstrap/README.md](../bootstrap/README.md) has the order.

## Conventions

### One directory, one Stack

Everything about a Stack lives in its directory: the compose file, its Komodo
declaration, its Caddyfile or Corefile if it has one, its Dockerfile if it is
built, its encrypted secrets. Adding a service is copying a directory; removing
one is deleting a directory, and the Komodo resource goes with it.

A Stack holds more than one Service only when the containers must be created and
destroyed together. Exactly one does: `download`, because qbittorrent uses
`network_mode: service:gluetun` and recreating gluetun alone leaves qbittorrent
silently unrouted ([ticket 06](../.scratch/unraid-gitops/issues/06-qbittorrent-vpn-topology.md)).
`network_mode: service:` cannot cross compose projects, so this is a hard
constraint, not a preference.

### Komodo declarations sit with what they declare

`stacks/<name>/komodo.toml` holds the `[[stack]]` — and the `[[build]]` too,
where the Stack is built rather than pulled. `komodo/` holds only what isn't
per-Stack: the ResourceSync itself, the Server, and the reconcile Procedure.

### The reconcile loop

`komodo/procedures.toml` holds one Procedure, `reconcile`, on a 15-minute cron.
Stage one runs the ResourceSync — a sync **applies nothing on poll**, it only
reports pending changes, so something has to execute it. Stage two runs
`BatchDeployStackIfChanged` over an **explicit list of Stack names**.

**Never widen that list to `*`.** A Stack that Komodo adopted but never deployed
has no deployed contents to diff, and `DeployStackIfChanged` treats that as
"deploy it" — so a wildcard recreates `plex` and the gluetun/qbittorrent pair
unattended, which is [ticket 06](../.scratch/unraid-gitops/issues/06-qbittorrent-vpn-topology.md)'s
silent-orphan hazard. Adding a Stack to the pattern is a step of migrating it.

### Config files a Stack's own service reads

`DeployStackIfChanged` diffs **tracked files**, and the only tracked file is the
compose file. A Stack whose service reads config out of the repo must list those
files, or a push that edits one changes nothing:

```toml
config_files = [
  { path = "config/services.yaml", requires = "restart" },
]
```

`restart` where the file arrives through a bind mount, `redeploy` where the
container reads it only at creation. Homepage is the case this exists for.

Every `[[stack]]` sets `project_name` explicitly. For the three containers
Portainer runs today (plex, gluetun, qbittorrent) it must match the existing
compose project name, which is how they are adopted rather than duplicated.

### Shared config comes from `common.env`

```toml
# stacks/sonarr/komodo.toml
additional_env_files = ["../../common.env"]
```

```yaml
# stacks/sonarr/compose.yaml
environment:
  PUID: ${PUID}
  PGID: ${PGID}
  UMASK: ${UMASK}
  TZ: ${TZ}
volumes:
  - ${APPDATA}/sonarr:/config
  - ${MEDIA}/tv:/tv
  - ${MEDIA}/downloads:/downloads
```

Named `common.env`, not `.env`, because Komodo generates its own `.env` in each
run directory from the Stack's `environment` field, and a name collision there
is silent.

[Ticket 09](../.scratch/unraid-gitops/issues/09-unify-uid-gid.md) settled the
values, and [common.env](../common.env) now holds them: `PUID=99`, `PGID=100`
(nobody:users, Unraid's own convention, no per-service exceptions), `UMASK=002`,
`TZ=America/Vancouver`, `APPDATA=/mnt/user/appdata` and
`MEDIA=/mnt/user/Media`.

> **Unverified.** That a relative path escaping the run directory resolves in
> `additional_env_files` has not been tested on the box. Verify it in
> [ticket 11](../.scratch/unraid-gitops/issues/11-stand-up-komodo.md); if it does
> not, the fallback is a symlink per Stack, not eleven copies of the values.

`mise` does not enter into this. Its `[env]` block configures the human's laptop
(`SOPS_AGE_KEY_FILE` and friends) — it never runs on the box, so it cannot be
where compose values live.

### Appdata paths

`${APPDATA}/<stack>` → `/config`, with two exceptions carried over as found:

- plex is `${APPDATA}/plexmediaserver`
- calibre also binds `${MEDIA}/books` → `/config/Calibre Library` — note the
  space in the container path

### Media paths

Media binds are **per category, exactly as the box already has them** —
`${MEDIA}/tv` → `/tv`, `${MEDIA}/downloads` → `/downloads`, and so on. No
service gets `${MEDIA}` mounted whole.

This is deliberate, and [ticket 09](../.scratch/unraid-gitops/issues/09-unify-uid-gid.md)
holds the reasoning. The alternative — one `${MEDIA}` → `/media` mount
everywhere, as the TRaSH guides describe — exists to enable hardlinked imports,
and hardlinks cannot pay off here: the array is six XFS disks under one shfs
overlay with a 39 TB library spread across them, so a download and its library
destination land on the same physical disk only by chance. Going single-mount
would have cost stored-path surgery in five services' databases and bought
nothing. **Do not "tidy" these binds into a single mount** without reopening 09.

### Secrets

Per [ticket 03](../.scratch/unraid-gitops/issues/03-secrets-handling.md), and
dotenv rather than YAML because the consumer is `--env-file`:

- `secrets.sops.env` — encrypted, committed, sits in the Stack directory
- `secrets.env` — decrypted on the box, gitignored, never committed
- one root `.sops.yaml`, one creation rule (`path_regex: \.sops\.env$`), one age
  recipient. There is one key, so per-Stack rules would be ceremony with nothing
  in them.

**`secrets.env` reaches the container through compose, not through Komodo**
([ticket 08](../.scratch/unraid-gitops/issues/08-deploy-homepage.md)):

```yaml
env_file:
  - path: secrets.env
    required: false      # it does not exist on a laptop, where `just lint` runs
```

Komodo's `additional_env_files` is for values compose needs to *interpolate*;
this is for values the process needs. And an entry there is **tracked by
default** — Komodo reads, diffs and validates it against the repo, where
`secrets.env` by design never is. If a Stack ever does need one interpolated,
the entry has to say so: `{ path = "secrets.env", track = false }`.

Four Stacks carry secrets: `download` (the NordVPN key), `calibre` (the GUI
password), `caddy` (the Cloudflare token) and `homepage` (the *arr API keys).
The *arr Stacks themselves carry none — their API keys live in their own
appdata, and only homepage needs to be told them.

### `pre_deploy` on every Stack

Every Stack has a `pre_deploy`, and every one of them starts by making sure the
shared network exists:

```toml
pre_deploy.command = """
docker network inspect shared >/dev/null 2>&1 || docker network create shared
"""
```

Stacks with secrets append the decrypt:

```toml
pre_deploy.command = """
docker network inspect shared >/dev/null 2>&1 || docker network create shared
sops -d secrets.sops.env > secrets.env
"""
```

Repeated in eleven files on purpose. It is order-independent, it survives a box
rebuild without anyone remembering a step, and it lives in git — which the
alternatives (one Stack owning the network, or a hand-run `docker network
create`) each give up one of.

### The shared network

One external bridge named `shared`, joined by everything:

```yaml
networks:
  shared:
    external: true
```

It carries Caddy's discovery traffic *and* the *arr → qbittorrent path. gluetun
must be on it either way — it owns qbittorrent's namespace, so it answers on
`:30024` for the *arr and it carries qbittorrent's `caddy` labels — which leaves
a second network separating nothing.

**One exception, added by [ticket 08](../.scratch/unraid-gitops/issues/08-deploy-homepage.md):
`dockerproxy`.** `shared` is what Caddy must reach; the read-only docker API is
the opposite — a thing only its one consumer should reach. So it gets a network
of its own, created `--internal` in `pre_deploy` like `shared` is, and a Stack
that needs the docker API joins both. The test for a second network is whether
the traffic is service-to-service and privileged; "these two containers talk" on
its own is not enough.

### Routing lives in labels

```yaml
labels:
  caddy: sonarr.rbrb.in
  caddy.import: internal
  caddy.reverse_proxy: "{{upstreams 8989}}"
```

Global Caddy config and the `(internal)` snippet live in a real file,
`stacks/caddy/Caddyfile`, bind-mounted into the container — Caddyfile syntax
stays Caddyfile syntax, and a reviewer meeting `caddy.import: internal` has one
place to go to learn what it admits.

**qbittorrent is the exception.** Its labels sit on the gluetun Service, because
a container in another container's namespace has no network identity of its own.
Anything that assumes labels live on the container being fronted breaks here.

### Default-deny, and the check that enforces it

Every fronted Service is `internal` unless it explicitly declares otherwise:

```yaml
services:
  status:
    x-published: true       # INTERNET-FACING — deliberate
    labels:
      caddy: status.rbrb.in
```

`scripts/check-exposure.sh` asserts that every Service with a `caddy:` hostname
label carries either `caddy.import: internal` or `x-published: true` — and
exactly one of them, since declaring both makes the intent unreadable. It runs
from `just lint` and from CI on every push and PR
([ticket 13](../.scratch/unraid-gitops/issues/13-local-tooling.md)). A forgotten
label fails the check instead of quietly widening what the box answers to, and
`x-published` is the one grep that says what faces the internet.

Labels are read in both compose forms — the `key: value` map above and the
`- key=value` list — so reformatting cannot sidestep the check, and a compose
file the script cannot parse fails rather than passing silently.

Nothing is published today
([ticket 05](../.scratch/unraid-gitops/issues/05-remote-access.md)).

### Ports

Ordinary Stacks publish `<host>:<container>`. CoreDNS is the odd one and the
convention accommodates it rather than fighting it — a full explicit bind:

```yaml
ports:
  - "100.126.56.26:53:53/udp"
  - "100.126.56.26:53:53/tcp"
```

### Image tags

Version *and* digest, in one string, matching the `~/home-ops` habit:

```yaml
image: ghcr.io/home-operations/sonarr:4.0.19.2995@sha256:e679d9abf64f7a…
```

The digest is what actually pins; the version tag is what a human reads. Both in
the image reference and both maintained by Renovate, so the readable part cannot
drift the way a comment beside it would.

**There is no exception.** This section previously carved one out for Caddy, on
the grounds that a locally built image has no registry digest to pin.
[Ticket 12](../.scratch/unraid-gitops/issues/12-image-update-strategy.md)
removed the build entirely, so the carve-out went with it — every image in the
repo is `version@digest`, without qualification.

12 also settled the mechanism: **Renovate, and only Renovate.** Komodo's
`poll_for_updates` / `auto_update` are used nowhere, and could not be — a pinned
digest cannot drift, so polling would never find anything. Minor and patch bumps
automerge; `download`, `plex`, `caddy` and `coredns` are human-merged, and
`bootstrap/` is human-merged *and* hand-applied.

### Restart policy

`restart: unless-stopped`, everywhere, stated explicitly in every compose file.

Unraid's autostart list is keyed by **container name**, so unraid and compose
will race for any container unraid still autostarts. **Turn unraid's autostart
off for a container before compose takes it over** — the ordering is part of
adopting, not an afterthought.

### Built images

**Nothing in this repo is built.** Every image is pulled from a registry and
pinned by digest, including Caddy.

Caddy was going to be the exception — `caddy-docker-proxy` and
`caddy-dns/cloudflare` must be compiled into one binary
([ticket 04](../.scratch/unraid-gitops/issues/04-reverse-proxy-and-domain.md)) —
until [ticket 12](../.scratch/unraid-gitops/issues/12-image-update-strategy.md)
found `ghcr.io/serfriz/caddy-cloudflare-dockerproxy`, which is that build,
maintained upstream and tagged by Caddy version. So there is no Dockerfile, no
Komodo `Build`, and no build stage in the reconcile Procedure.

If a future service does need building, build it in **GitHub Actions** and push
to GHCR — never on the box, where a build competes with the thing running the
deploys. 12 records the escape hatch for Caddy specifically, should serfriz go
stale.

### Recipes

Decided by [ticket 27](../.scratch/unraid-gitops/issues/27-recipe-safety-convention.md).
Some `just` recipes cannot change anything and some can move the box out from
under you, and `just --list` gives no clue which is which. The rule:

> **`--apply` guards a recipe that changes the box in a way the reconcile loop
> would not.**

The test is **provenance, not blast radius** — did a committed file already say
to do this? `just reconcile` is a big act and stays ungated, because the
15-minute cron performs the identical Procedure whether anyone types it or not;
running it only makes the box arrive sooner at the state `main` already
describes. The decision was the merge, and [ticket 12](../.scratch/unraid-gitops/issues/12-image-update-strategy.md)
already put the guard there with its four human-merge carve-outs. `just
bootstrap` and `just host-ports` are the opposite: nothing else will ever run
them, so typing them *is* the decision.

| recipe | reaches | gated |
|---|---|---|
| `default`, `lint`, `verify-secrets`, `host-check` | local / read-only | no |
| `secret <stack>` | a repo file, via `$EDITOR` | no — the repo is not the box |
| `reconcile` | Komodo API | no — the cron does this anyway |
| `bootstrap` | Komodo API | **`--apply`** |
| `host-ports` | the box over SSH | **`--apply`** |

A gated recipe:

- takes `*args` in the justfile and passes them through; **the script parses the
  flag**, not `just`
- names the flag `--apply`, and takes no other
- **defaults to a dry run** that reports an overview of what would happen and
  changes nothing. Not the exact command it would send — an overview is what
  gets read
- exits 0 with a plain "nothing to do" when there is nothing to do
- ends its `just --list` comment with `-- pass --apply to commit`, so the
  gating is visible at the moment of choosing. **The absence of that phrase is
  itself a claim**, so an ungated recipe must be genuinely ungated

There is no confirmation prompt anywhere. A prompt cannot run unattended and
trains you to hit `y` without reading; making you read the dry run and then
retype the command is a real pause rather than a reflex.

What a dry run *is* differs per recipe, and the rule does not pretend otherwise.
`host-ports` diffs the snapshot against the box field by field, because desired
state is a file. `bootstrap` reports only whether the ResourceSync already
exists — the question actually being asked there is *is there anything to
bootstrap*, since the danger is not the fresh box (where nothing exists) but a
later run against a live Komodo.
