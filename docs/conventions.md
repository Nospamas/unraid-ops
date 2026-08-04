# Conventions

The standing rules of this repo. Vocabulary is in [CONTEXT.md](../CONTEXT.md);
the routine for adding a service is in [adding-a-service.md](adding-a-service.md).

This file holds the rules. `[NN]` cites the ticket that decided one and holds the
reasoning — `.scratch/unraid-gitops/issues/NN-*.md`. `adding-a-service.md` holds
the templates to copy.

| read | when |
|---|---|
| [The tree](#the-tree) | finding where something goes |
| [Stacks](#stacks) | adding or removing a directory under `stacks/` |
| [The reconcile loop](#the-reconcile-loop) | a change has to reach the box |
| [Alerting](#alerting) | something must be noticed when it breaks |
| [Tracked files](#tracked-files) | the service reads config out of the repo |
| [Shared config](#shared-config) | writing `compose.yaml` or `komodo.toml` |
| [Paths](#paths) | binding appdata or media |
| [Ownership and modes](#ownership-and-modes) | a service writes media or appdata |
| [Secrets](#secrets) | the Stack has a secret |
| [`pre_deploy`](#pre_deploy) | writing `komodo.toml` |
| [Networks](#networks) | two containers must talk |
| [Routing](#routing) | the service has a web UI |
| [Default-deny](#default-deny) | anything is fronted by Caddy |
| [Addressing](#addressing) | deciding how something reaches a service |
| [Images](#images) | picking or bumping an image |
| [Restart policy](#restart-policy) | writing `compose.yaml`, or adopting |
| [Recipes](#recipes) | adding a `just` recipe |

## The tree

```
common.env          shared config, read by every Stack
.sops.yaml          one creation rule: *.sops.env → the age recipient
.mise.toml          pinned local tools + SOPS_AGE_KEY_FILE
justfile            local commands
.renovaterc.json5   mise pins and image bumps
CLAUDE.md           the rules that are expensive to break by accident
CONTEXT.md          glossary

bootstrap/          Komodo's own four containers, run by hand, never reconciled
  host/ident.cfg    the only host state git owns -- the GUI's ports [15, 26]
komodo/             sync.toml (the ResourceSync + the Server), procedures.toml
scripts/            check-exposure.sh, komodo.sh, host.sh

stacks/<name>/      komodo.toml + compose.yaml, always
  conf/Caddyfile    caddy only — global options + the (internal) snippet
  conf/Corefile     coredns only
  config/           homepage only — git owns these outright, they are files
  secrets.sops.env  caddy, homepage, download, calibre
```

Eleven Stacks, twelve containers: `caddy`, `coredns`, `homepage`,
`dockerproxy`, `download` (gluetun + qbittorrent), `sonarr`, `radarr`,
`prowlarr`, `lazylibrarian`, `plex`, `calibre`. Built so far: `dockerproxy`,
`homepage`, `caddy`, `coredns`, the four *arr Stacks [21], `calibre` [22] and
`plex` [23] and `download` [24]. Nothing is left to migrate.

`bootstrap/` is in git so a rebuild starts from a file, and **never gets a
`komodo.toml`**: Core can redeploy itself but Periphery cannot, and upstream
requires the two match versions [12]. Its `secrets.sops.env` is decrypted **by
hand**, because the thing that runs `pre_deploy` is what is being installed —
[bootstrap/README.md](../bootstrap/README.md) has the order.

## Stacks

Everything about a Stack lives in its directory: the compose file, its Komodo
declaration, its Caddyfile or Corefile, its encrypted secrets. Adding a service
is copying a directory; removing one is deleting a directory. `komodo/` holds
only what is not per-Stack — the ResourceSync, the Server, the Procedure.

A Stack holds more than one Service **only when the containers must be created
and destroyed together**. Exactly one does: `download`, because qbittorrent uses
`network_mode: service:gluetun`, which cannot cross compose projects, and
recreating gluetun alone leaves qbittorrent silently unrouted [06].

Every `[[stack]]` sets `project_name` explicitly. **[adopt]** it must match the
project the container already belongs to, or Komodo builds a second copy
alongside the running one instead of taking it over.

**A container from unraid's Docker tab has no project to match** [21]. It
carries `net.unraid.docker.managed=dockerman` and no `com.docker.compose.*`
labels at all, so nothing can adopt it — `just adopt <container>` removes it,
and the Stack rebinds the same appdata. Only Portainer's three (`plex`,
`gluetun`, `qbittorrent`) are adoptable in place.

## The reconcile loop

`komodo/procedures.toml` holds one Procedure, `reconcile`, on a 15-minute cron.
Two stages, because a ResourceSync **applies nothing on its own** — it only
reports pending changes:

1. `RunSync`
2. `BatchDeployStackIfChanged`, over an **explicit list of Stack names**

**Never widen that list to `*`.** A Stack that Komodo adopted but never deployed
has no deployed contents to diff, and `DeployStackIfChanged` reads that as
*deploy it* — so a wildcard recreates the gluetun/qbittorrent pair unattended
[06] [08]. Adding a Stack to the pattern is a step of migrating it.

Drive it with `just reconcile`, not the UI and not ad-hoc API calls. A new
operation goes in [scripts/komodo.sh](../scripts/komodo.sh) behind a recipe.

**The scheduled Procedure cannot apply a change to this file** [16]. Komodo
refuses to update a Procedure while it is running, and the Procedure *is* what
runs the sync that would update it — ten retries, then
`procedure sync loop exited after max iterations` with the real reason
discarded, and no Stack deploys at all.

`just reconcile` runs the sync **bare first**, then the Procedure, which is why
one command still covers it; the Procedure's own sync stage then finds no
changes. But **the cron only runs the Procedure**, so a `procedures.toml` edit
that lands without `just reconcile` fails every 15 minutes until someone runs
it. That failure is now loud rather than silent — see below.

## Alerting

Two paths, one destination, and they cover different failures [29]:

| path | catches |
|---|---|
| Komodo Alerter, `komodo/alerters.toml` | `ProcedureFailed`, `StackStateChange`, `ServerUnreachable` — the loop itself failing |
| gatus, `stacks/gatus/conf/config.yaml` | a service that answers wrongly while its container stays `Up` |

Both publish to the `ntfy` Stack, which an Android client subscribes to directly
over the tailnet.

**A green reconcile is not a running service, and Komodo cannot tell you
otherwise.** All three silent failures this map has seen were containers left
`Up` — a stale bind [16], then three containers with no networks at all [21].
`DeployStackIfChanged` compares a config hash, so a correct hash over a broken
container reports success. `StackStateChange` does not help either: it fires on
a *mix* of container states, and there was no mix. Only an end-to-end request
sees it, which is what gatus is for.

**The alert path must not traverse the thing it reports on.** Routing alerts
through Caddy would mean a Caddy outage silences the alert about the Caddy
outage. So `ntfy` carries no `caddy` label and binds the tailnet address
directly, and gatus keeps `:8090` alongside `status.rbrb.in`.

**gatus is host-networked** [16]'s reason, not a preference: a probe from a
bridge address arrives at host-networked Caddy as `172.20.x.x` and the
`(internal)` guard 403s it before `reverse_proxy` runs. Every probe would fail
identically, and a 403 proves the guard works, never that a backend is alive.

**Probe an exact status, not `< 400`.** Six of the ten services answer something
other than 200 when unauthenticated — 302, 303 and 401 are all healthy. The two
signatures worth knowing: **404** is Caddy having discarded the block and the
`*.rbrb.in` wildcard catching the request [16]; **502** is Caddy holding the
block but unable to reach the container [21].

**Alert on sustained failure.** 60s interval, three consecutive failures. A
reconcile that legitimately redeploys a Stack takes it down for seconds, and
paging on that is how a channel gets muted; short blips stay visible in the
status page's history.

**Nothing watches tower from off tower.** ntfy and gatus both die with the box,
so silence is indistinguishable from health. Closing that needs home-ops probing
tower over the tailnet — see [29]'s brief. Until it lands, `stacks/ntfy/**` and
`stacks/gatus/**` are human-merge in Renovate, because nothing would notice a bad
bump to the watcher.

## Tracked files

`DeployStackIfChanged` diffs **tracked files**, and by default the only tracked
file is the compose file. A Stack whose service reads config out of the repo
must list it, or a push that edits it changes nothing [08]:

```toml
config_files = [
  { path = "config/services.yaml", requires = "restart" },
]
```

`restart` where the file arrives through a bind mount, `redeploy` where the
container reads it only at creation.

**Bind the directory, never the file** [16]. A git pull replaces a file instead
of writing it in place, and the run directory is on shfs — so a single-file bind
goes `stale file handle` the first time the file changes, and stays broken.
That is why the Caddyfile is `conf/Caddyfile` and not `Caddyfile`. It fails
quietly: Caddy dropped every site block that imported the snippet it could no
longer read, and the reconcile still reported success.

## Shared config

Every Stack reads `additional_env_files = ["../../common.env"]` — the relative
path is verified to resolve on the box [11]. [common.env](../common.env) holds
`PUID=99`, `PGID=100` (nobody:users, Unraid's own convention, **no per-service
exceptions**), `UMASK=002`, `TZ=America/Vancouver`,
`APPDATA=/mnt/user/appdata`, `MEDIA=/mnt/user/Media` [09].

Named `common.env`, not `.env`, because Komodo generates its own `.env` in each
run directory and a name collision there is silent. `mise` does not enter into
this — its `[env]` block configures the laptop and never runs on the box.

## Paths

`${APPDATA}/<stack>` → `/config`, with two exceptions carried over as found:

- plex is `${APPDATA}/plexmediaserver`, and also binds `${APPDATA}/transcode` →
  `/transcode`, which is the path its own `TranscoderTempDirectory` names [23]
- calibre also binds `${MEDIA}/books` → `/config/Calibre Library` — the space in
  that container path is real

Media binds are **per category, exactly as the box already has them** —
`${MEDIA}/tv` → `/tv`, `${MEDIA}/downloads` → `/downloads`. No service gets
`${MEDIA}` mounted whole.

**plex's media binds are `/mnt/<category>`**, not `/<category>` [23]. Its library
paths live in its database, so the prefix is not a style choice.

**Do not "tidy" these into a single `/media` mount.** It is the TRaSH layout and
it exists for hardlinked imports, which cannot pay off on six XFS disks under one
shfs overlay — [09] ruled hardlinks out of scope on the evidence, and reversing
that means reopening it.

## Ownership and modes

`PUID=99`, `PGID=100`, **`UMASK=002`** — all three, on every service that writes
[09]. Dirs land 775 and files 664.

**`UMASK=022` is a bug, not a default.** `nobody`(99), `share`(1000) and
`rseaforthb`(1001) all have primary gid **100**, so group-write is what lets the
humans and the containers share a tree. At 022 a container creates 755
directories that nobody else can rename or delete into — and moving a file needs
write on the **parent directory**, not the file. That is what put the box on
`chmod -R 777`, and 777 is what [19] removed. Nothing here needs it back.

Samba is not involved: its effective `create mask` and `directory mask` are both
0777, so it strips nothing. Do not "fix" `smb-extra.conf`.

`just permissions` re-normalises the tree; `just permissions-audit` reports it
without changing anything. Both prune the paths that must **not** be group-
readable — `komodo/{postgres,ferretdb,keys,backups}`, `caddy/data` — and appdata
is adjusted **relatively** (`o-w`, `g+w`), never to an absolute mode, because an
absolute 664 strips the execute bit from `komodo/bin/sops` and from the codecs
plex downloads into its own appdata and then runs.

## Secrets

Dotenv rather than YAML, because the consumer is `--env-file` [03]:

- `secrets.sops.env` — encrypted, committed, in the Stack directory
- `secrets.env` — decrypted on the box by `pre_deploy`, gitignored, never
  committed
- one root `.sops.yaml`, one creation rule (`path_regex: \.sops\.env$`), one age
  recipient

Write one with `just secret <stack>`. `sops --encrypt` on a path outside a Stack
directory finds no creation rule at all.

**`secrets.env` reaches the container through compose's `env_file`, not through
Komodo** [08], with `required: false` so `just lint` still runs on a laptop.
`additional_env_files` is for values compose must *interpolate*, and an entry
there is **tracked by default** — Komodo would diff `secrets.env` against a repo
it is deliberately absent from. A Stack that genuinely needs one interpolated
must say `{ path = "secrets.env", track = false }`.

## `pre_deploy`

Every Stack has one, and every one starts by creating the `shared` network
idempotently; Stacks with secrets then append the decrypt — **inside a subshell
that sets `umask 077`** [19]:

```
(umask 077; sops -d secrets.sops.env > secrets.env)
```

A bare redirect creates the plaintext 0666 masked by Periphery's umask, which is
0022 — a world-readable secret. The subshell rather than a `chmod` afterwards,
because it closes the window instead of reopening it. `just lint` enforces this.

Repeated in every file **on purpose** [07]: it is order-independent, it survives
a box rebuild with nobody remembering a step, and it lives in git — which one
Stack owning the network, or a hand-run `docker network create`, each give up.

**`pre_deploy` runs inside Periphery, so it only sees what Periphery binds** [29].
Every command here before 29 touched the docker socket or the run directory,
both of which it does see — so this went unnoticed until a `mkdir -p` and
`chown` on a Stack's appdata created a correct directory inside Periphery's own
filesystem, invisible to everything, while docker made the real bind target
`root:root` on the host. It failed with a green deploy and a container in a
restart loop. `bootstrap/compose.yaml` now binds the whole of
`/mnt/user/appdata`, which costs nothing given the socket is already there. **A
path outside that bind is still a no-op that reports success.**

## Networks

One external bridge named `shared`, joined by everything and declared `external`
in every Stack, because Komodo runs each Stack as its own compose project. It
carries Caddy's discovery traffic *and* the *arr → qbittorrent path; gluetun must
be on it either way, since it owns qbittorrent's namespace.

**Two exceptions.** `dockerproxy` [08] is on its own `--internal` network,
created in `pre_deploy` the same way; the test for a second network is whether
the traffic is service-to-service **and** privileged — "these two containers
talk" is not enough.

`caddy` is `network_mode: host` and joins nothing [16]. Tailscale masquerades
any packet it routes onward and docker's DNAT counts, so behind published ports
every tailnet client arrives as the bridge gateway and the guard below 403s the
tailnet. Caddy still reaches every Service by its `shared` address, which is
what `CADDY_INGRESS_NETWORKS` names now that there is nothing to auto-detect.

## Routing

Routing lives in `caddy` labels on the Service. Caddy's global config and the
`(internal)` snippet live in a real file, `stacks/caddy/conf/Caddyfile`,
bind-mounted in. That file also carries the two hostnames Caddy serves for
things that are not Stacks — `komodo.rbrb.in` and `unraid.rbrb.in` [26].

**qbittorrent is the exception**: its labels sit on the gluetun Service, because
a container in another container's namespace has no network identity of its own.

## Default-deny

Every fronted Service is `internal` unless it declares `x-published: true`.
`scripts/check-exposure.sh` asserts that every Service with a `caddy:` hostname
carries **exactly one** of `caddy.import: internal` or `x-published: true`. It
runs from `just lint` and from CI [13]. Both compose label forms are read, and
a compose file the script cannot parse **fails** rather than passing silently.

`x-published` is the one grep that says what faces the internet. Nothing is
published today [05].

The guard is verified, not assumed [16]: LAN and tailnet clients get 200, and
127.0.0.1 and a container on `shared` both get 403. It depends on Caddy seeing
the real client address, so it is only sound while Caddy is host-networked.

## Addressing

Humans reach a service at its `*.rbrb.in` hostname; containers reach each other
by container name on `shared` [26]. **Neither is ever the box's address.**
`192.168.1.195` is a DHCP lease, so an in-app URL pointing at it is a setting
with an expiry date, and it lives in appdata where git cannot fix it [30].

A host port is for traffic that is neither, and the Service must say which with
`x-host-port` — checked by `check-exposure.sh`, which fails a `ports:` block
without one:

```yaml
plex:
  x-host-port: non-browser clients; plex.tv advertises this address to them [23]
  ports:
    - "32400:32400"
```

Three reasons qualify. `just lint` checks only that one is stated:

- **a client configured by address, not by name** — CoreDNS, because tailscale's
  Split DNS row takes an IP [17].
- **plex's `32400`** [23], which is its own case and not a general licence.
  plex.tv advertises that address to clients and rb's router forwards it, so the
  port is a published path Caddy does not carry and `x-published` does not
  describe — see [31] before touching it.
- **a backup path to whatever detects or repairs a Caddy outage** [26] [29].
  Komodo (`:9120`) and the Unraid GUI (`:8008`) answer at `*.rbrb.in` *and* keep
  their host port, because the tooling that fixes the proxy must not sit behind
  it. Neither is a Stack, so neither carries the key. [29] widened *repairs* to
  *detects*: gatus keeps `:8090` alongside `status.rbrb.in`, and `ntfy` takes no
  hostname at all, because an alert routed through Caddy cannot report on Caddy.

Nothing else. A host port for a browser is the rule being broken, not a fourth
reason.

CoreDNS binds a full explicit address, because it must not answer on the LAN [05]
— and `ntfy` follows it for the same reason, at `100.126.56.26:8095`:

```yaml
ports:
  - "100.126.56.26:53:53/udp"
  - "100.126.56.26:53:53/tcp"
```

**The rest of the box's host state is not git's** [26]. `ident.cfg`'s Management
Access fields are the whole of it, because a fresh flash puts nginx back on
80/443 where Caddy cannot bind [15]. `network.cfg`, `docker.cfg`, `shares/`,
`plugins/` and the licence and password files were each tested against "would
losing this break the stack or the rebuild" and each failed it.

## Images

Version **and** digest, in one string, **no exceptions** —
`sonarr:4.0.19.2995@sha256:e679d9…`. The digest pins; the version tag is what a
human reads. Both are maintained by Renovate, so the readable part cannot drift.

**Renovate, and only Renovate** [12]. Komodo's `auto_update` and
`poll_for_updates` are used nowhere and could not be — a pinned digest cannot
drift. Minor and patch bumps automerge; `download`, `plex`, `caddy` and `coredns`
are human-merged, and `bootstrap/` is human-merged *and* hand-applied.

**An image that updates itself at runtime is not pinned** [23]. plex's `VERSION`
names a Plex Media Server build to fetch and install at every container start;
set to anything but `docker` it makes the digest describe a container that no
longer exists by the time it serves. `VERSION: docker` is what puts the image
back in charge, and it is what lets Renovate see the version at all.

**Nothing in this repo is built.** Caddy was going to be the exception until [12]
found `ghcr.io/serfriz/caddy-cloudflare-dockerproxy`, which is that build,
maintained upstream. If a future service does need building, build it in **GitHub
Actions** and push to GHCR — never on the box, where a build competes with the
thing running the deploys.

## Restart policy

`restart: unless-stopped`, stated explicitly in every compose file.

**[adopt]** Unraid's autostart list is keyed by **container name**, so unraid and
compose race for any container unraid still autostarts. Turn unraid's autostart
off **before** the first deploy — `just adopt` does it alongside the removal.

## Recipes

> **`--apply` guards a recipe that changes the box in a way the reconcile loop
> would not.**

The test is **provenance, not blast radius** — did a committed file already say
to do this? [27]

| recipe | reaches | gated |
|---|---|---|
| `default`, `lint`, `verify-secrets`, `host-check` | local / read-only | no |
| `secret <stack>` | a repo file, via `$EDITOR` | no — the repo is not the box |
| `reconcile` | Komodo API | no — the cron does this anyway |
| `bootstrap` | Komodo API | **`--apply`** |
| `host-ports` | the box over SSH | **`--apply`** |
| `adopt <container>` | the box over SSH | **`--apply`** |

`adopt` has **no use left on this route** — since [22] the only container
unraid's Docker tab still owns is `PortainerCE`, which [25] retires rather than
adopts, and a rebuilt box is a fresh unraid install populated from git. It
takes a container name rather than a Stack, so it keeps working for anything
later installed from Community Applications.

`reconcile` is a big act and stays ungated: the cron performs the identical
Procedure whether anyone types it or not, so the decision was the merge, where
[12]'s human-merge carve-outs already put the guard.

A gated recipe:

- takes `*args` in the justfile and passes them through; **the script parses the
  flag**, not `just`
- names the flag `--apply`, and takes no other
- **defaults to a dry run** that reports an *overview* of what would happen and
  changes nothing — not the exact command it would send
- exits 0 with a plain "nothing to do" when there is nothing to do
- ends its `just --list` comment with `-- pass --apply to commit`. **The absence
  of that phrase is itself a claim**, so an ungated recipe must be genuinely
  ungated

There is no confirmation prompt anywhere: a prompt cannot run unattended and
trains you to hit `y` without reading.

What a dry run *is* differs per recipe. `host-ports` diffs the snapshot against
the box field by field. `bootstrap` reports only whether the ResourceSync already
exists, since the danger is not the fresh box but a later run against a live
Komodo.

---

This file was `docs/repo-layout.md` until [28], which renamed it, indexed it,
and cut the reasoning out to the tickets. [07] decided the original layout.
