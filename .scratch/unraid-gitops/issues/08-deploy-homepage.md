# 08 — Deploy homepage from the repo

Type: task
Status: closed
Assignee: Nospamas
Blocked by: 03, 07, 10, 11

## Question

The proving case. Stand homepage up under the repo's control end to end, so that
a `git push` changes what the dashboard shows.

**The mechanism is Komodo** ([02](02-choose-reconcile-mechanism.md)), installed
by [11](11-stand-up-komodo.md) and pointed at the remote from
[10](10-publish-repo-to-remote.md) — so by the time this ticket runs, the loop
exists and is reconciling nothing. All this ticket adds is the first thing for
it to reconcile.

**Reconcile is poll, not webhook.** Per 02, a GitHub webhook needs an inbound
path the box does not have until [05](05-remote-access.md); the loop is a Komodo
Procedure on a cron schedule running `BatchDeployStackIfChanged`. So "without a
manual step" means *within the poll interval*, not *instantly* — set the
interval deliberately and record it.

**This is a greenfield deploy, not a migration.**
[01](01-inventory-running-containers.md) found no homepage container, no
`/mnt/user/appdata/homepage`, and no homepage YAML anywhere on the box. That
removes all adoption risk from the proving case — nothing here can lose data —
so what it actually proves is the reconcile loop and the ticket 07 layout, in
isolation. Good: a failure here is unambiguous.

Homepage is the right first service because git owns *everything* about it — its
config is plain YAML files (`settings.yaml`, `services.yaml`, `bookmarks.yaml`,
`widgets.yaml`, `docker.yaml`), so it exercises both halves of the reconcile: the
container definition *and* the app's own config.

Do:

- Write homepage's container definition using the layout from ticket 07.
- Decide where its appdata goes — `/mnt/user/appdata/homepage` does not exist
  yet, so this is the one service whose on-disk layout is a free choice.
- Pull the *arr API keys out of each service's `/config/config.xml` (per
  [01](01-inventory-running-containers.md) they are not environment variables,
  so nothing has captured them yet) and feed them through ticket 03's mechanism.
  Homepage is the only consumer.
- Port the config files across. The existing home-ops versions at
  `~/home-ops/kubernetes/apps/self-hosted/homepage/app/config/` are a good
  starting shape, but the `kubernetes.yaml` provider and every
  `*.svc.cluster.local` widget URL have no meaning here — the docker provider
  and container names replace them.
- Point `href`s at the hostnames from ticket 04. Widgets must cover all eight
  in-scope services, not the destination's five.
- Push a change and confirm the box picks it up without a manual step.

The answer records what the reconcile loop actually did on push, how long it
took, and anything about the layout that ticket 07 got wrong — that feedback is
what graduates the remaining service migrations out of the fog.

## Settled by [07](07-repo-layout-and-conventions.md)

The layout this ticket was waiting on exists — see
[docs/repo-layout.md](../../../docs/repo-layout.md) and the checklist in
[docs/adding-a-service.md](../../../docs/adding-a-service.md). For homepage
specifically:

- `stacks/homepage/` holds `komodo.toml`, `compose.yaml`, `config/` and
  `secrets.sops.env` (the *arr API keys).
- **`config/` is the one place git owns a service's own settings outright**,
  because homepage's config is plain YAML files rather than a database. That is
  what makes homepage the proving case: a `git push` that changes
  `config/services.yaml` visibly changes the dashboard.
- Homepage is fronted like anything else — `caddy: home.rbrb.in` plus
  `caddy.import: internal`, and `scripts/check-exposure.sh` will fail the repo if
  the second label is missing.

This ticket is the **first end-to-end exercise of the add-a-service checklist**.
If a step in it turns out to need a decision rather than a keystroke, that is a
defect in 07's answer — record it here and amend
[docs/adding-a-service.md](../../../docs/adding-a-service.md) rather than
deciding it ad hoc.

## Resolution (2026-08-02)

**A push changes the box, unattended, in under nine minutes.** Pushed at
22:21:37, the dashboard changed at 22:30:11 — 8m34s, no manual step, on a commit
that touched *nothing but* `config/bookmarks.yaml`. The reconcile loop, both
Stacks and the two recipes that drive them are in the repo; `plex`, `download`
and every other running container were untouched throughout.

Verified on the box: homepage answers 200 on `tower:3000` and
`tower.gute-morpho.ts.net:3000`, the sonarr/radarr/prowlarr/plex widgets return
real data, and container tiles resolve through the socket proxy.

### What the loop actually is

`komodo/procedures.toml` — one Procedure, `reconcile`, cron `0 */15 * * * ?`,
two stages:

1. **`RunSync`**, because **a ResourceSync applies nothing on its own.** Core
   polls the files and *reports* pending changes; something must execute it.
   02 described the loop as `BatchDeployStackIfChanged` alone, which would have
   picked up edits to existing Stacks and never noticed a new one.
2. **`BatchDeployStackIfChanged`** over `"dockerproxy, homepage"` — **an
   explicit list, never `*`.** A Stack Komodo has adopted but never deployed has
   `deployed_contents: null`, and the code reads that as `FullDeploy`. A
   wildcard here would have recreated `plex` and the gluetun/qbittorrent pair
   unattended every 15 minutes — [06](06-qbittorrent-vpn-topology.md)'s
   silent-orphan hazard, on a timer. Adding a Stack to that line is now a step
   of migrating it.

15 minutes was chosen deliberately; **webhook is the intended end state** once
something inbound exists, which is fog until [16](16-deploy-caddy.md).

### The checklist had three defects, all now fixed in the docs

This was 07's first end-to-end exercise, and it needed three decisions the
checklist could not have answered:

- **`config_files`.** `DeployStackIfChanged` diffs *tracked* files, and tracks
  only the compose file. Without listing homepage's nine config files in
  `komodo.toml`, the entire premise of this ticket fails silently — a config
  push would reach the clone and change nothing. `requires = "restart"` is right
  for anything arriving through a bind mount, and it works: the 22:30 run was a
  **`RestartStack`**, not a redeploy — same container, restarted.
- **`secrets.env` belongs in compose's `env_file`, not `additional_env_files`.**
  Entries there are **tracked by default**, so Komodo would read, diff and
  validate a file the repo deliberately never contains. It also would not have
  worked: `additional_env_files` feeds compose *interpolation*, and every secret
  this repo has is one a container's process needs. `required: false` keeps
  `just lint` green on a laptop where the file cannot exist.
- **The deploy pattern is a per-Stack step**, per above.

Amended in [docs/repo-layout.md](../../../docs/repo-layout.md) and
[docs/adding-a-service.md](../../../docs/adding-a-service.md) rather than
decided here.

### Homepage: what it needed that no ticket predicted

- **It runs fine as uid 99** — `next-server` is pid 1 as uid 99. 09's
  no-exceptions rule holds; this service needed no carve-out.
- **`/app/config` must be writable.** Read-only serves HTTP 500. Homepage seeds
  any missing skeleton file at boot, so the repo ships **all nine** —
  `bookmarks custom.css custom.js docker kubernetes proxmox services settings
  widgets` — and the git clone on the box is consequently **clean**, verified.
  Ship a partial skeleton and the clone accumulates untracked files that collide
  the day git grows one by that name.
- **Its appdata is logs and nothing else.** `${APPDATA}/homepage/logs`, so the
  log file stays out of the working tree. Docker creates that target
  `root:root`, but homepage's entrypoint chowns it before dropping privileges —
  so 11's bind-mount trap does *not* bite here. It is image-dependent, not a
  general escape.
- **`HOMEPAGE_ALLOWED_HOSTS` rejects by Host header**, which is how the human
  found the MagicDNS name missing. `tower:3000` and
  `tower.gute-morpho.ts.net:3000` are now listed; all but `home.rbrb.in` go when
  16 fronts it.

### The docker socket, and a second network

Homepage's container tiles need the docker API, and upstream requires homepage
run **as root** to hold the socket — the first exception to 09, on a fronted web
app. Rejected. `stacks/dockerproxy/` runs
`ghcr.io/tecnativa/docker-socket-proxy` with `CONTAINERS=1, POST=0` instead, and
homepage reads `dockerproxy:2375`.

**It is not on `shared`**, at the human's direction, and the reasoning corrects
07: `shared` exists so Caddy can reach things, and a privileged read-only API is
the opposite — a thing exactly one consumer should reach. It gets its own
network, created `--internal` in `pre_deploy` (so that container has no route
off the box), and homepage joins both. Recorded in repo-layout as the test for
when a second network is earned.

### `just bootstrap` and `just reconcile`

The ResourceSync was first created by hand against Core's API. **The human
rejected that**, correctly: `bootstrap/README.md` stopped at step 7, so a
rebuilt box would have been a running Komodo that had never heard of this repo
— while repo-layout claimed "everything comes back through ResourceSync". The
one resource a sync cannot create was living only in a session transcript.

Now [scripts/komodo.sh](../../../scripts/komodo.sh) behind two recipes, reading
`komodo/sync.toml` so the TOML stays the single description, and step 8 of
[bootstrap/README.md](../../../bootstrap/README.md).

**This reverses [13](13-local-tooling.md)'s decline of a `reconcile` recipe**,
on the fact [11](11-stand-up-komodo.md) found: Core takes the **admin password**
at `/auth/login`, there is no API key, and that password is already in
`bootstrap/secrets.sops.env` which any clone with `age.key` decrypts. The second
local secret 13 refused to pay for does not exist. One laptop-side addition: the
LAN address in `compose.env` is unreachable off the LAN, so `.mise.toml` sets
`KOMODO_HOST=http://tower:9120` — mise's `[env]` being laptop config by 07's own
rule.

### Komodo facts worth carrying forward

- `managed = true` on a ResourceSync **forces delete mode on**, whatever its
  name suggests. Both `managed` and `delete` are `false` here, and must stay so
  while `plex` and `download` are adopted-but-undeclared.
- **Always read the pending diff before executing a sync.** This one's was 3
  creates and a self-update of the description — no deletions, nothing touching
  the adopted Stacks.
- Execute responses serialize the update id as `_id.$oid`; reads return it as
  `id`. Cost one broken poll in `komodo.sh`.
- A built-in **`Global Auto Update`** Procedure runs daily at 03:00. It is a
  no-op here and confirms [12](12-image-update-strategy.md): nothing sets
  `auto_update`, and a `version@digest` pin could not drift if it did.
- Komodo clones to `/mnt/user/appdata/komodo/stacks/<stack>/`, inside
  `PERIPHERY_ROOT_DIRECTORY` by construction — 11's `files_on_host` rule is
  satisfied for free by repo-backed Stacks.

### Secrets

Four new, all in `stacks/homepage/secrets.sops.env`: the sonarr, radarr and
prowlarr API keys, and plex's `PlexOnlineToken`. Encrypted **straight from the
box through a pipe** (`sops --encrypt --filename-override`), so no plaintext was
written to the working tree or printed — the route
[docs/adding-a-service.md](../../../docs/adding-a-service.md) warns against
having to take.

The plex token is not in the map's low-value class: it is account-scoped, not
service-scoped. It is encrypted at rest in git like the rest, but it is the
first secret here worth rotating if the repo's threat model ever changes.

Note for [19](19-secret-hygiene-on-the-box.md): `pre_deploy` writes
`secrets.env` **`644 root`**, inside the 777 tree 19 already owns.

### Two things that need no change, checked rather than assumed

- **qbittorrent's widget needs no credentials and no config edit.** Traffic to
  its published port arrives with a LAN source address, which its existing
  `AuthSubnetWhitelist` already admits. **This changes at migration**: once
  `download` is on `shared` and homepage addresses `gluetun:30024` directly, the
  source becomes `172.20.0.0/16` and that subnet must be added, or the widget
  starts failing for no visible reason.
- **Renovate needed no edit.** 12's `docker-compose` manager rule matches both
  new Stacks automatically, and neither is in the human-merge carve-outs. Still
  unproven against a live run — the weekend schedule is its first.

### Widgets do not cover all eight services, and cannot

The ticket asked for all eight. Six are covered: plex, sonarr, radarr, prowlarr,
qbittorrent, and gluetun by proxy. Two have no widget in homepage at all —
**lazylibrarian** (no such type) and **calibre** (homepage ships `calibre-web`,
a different application from the calibre this box runs). Both are link tiles
with container status. **gluetun** has a widget type but its control server is
unpublished on `:8000`, so nothing can reach it until `download` migrates.

### The restart does not loop — checked, because it looked like it might

After the config-only restart, `deployed_hash` still read the *previous* commit
while `latest_hash` read the new one, which looks exactly like a Stack that will
restart itself every 15 minutes forever. It does not. Komodo updates the
deployed **contents** after a restart-only change even though it leaves the hash
alone, and the diff is contents-based — verified both ways: the stored contents
match remote, and the 22:45 and 23:00 scheduled runs left the container from the
22:30 restart untouched.

So `deployed_hash` on a Stack whose last change was config-only is **cosmetically
stale, not a pending deploy**. Do not "fix" it by forcing a redeploy.
