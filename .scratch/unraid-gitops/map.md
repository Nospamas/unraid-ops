# Map: Unraid GitOps

## Destination

A `git push` to this repo reconciles the unraid box automatically, with sonarr,
radarr, prowlarr, qbittorrent (behind a VPN) and homepage all running from
definitions held here, fronted by a reverse proxy on a real domain and reachable
from outside the house.

## Notes

**Domain**: GitOps for Docker on Unraid — compose-style container definitions in
git, reconciled onto the host. Not Kubernetes; none of the Flux/Talos vocabulary
carries over.

**Execution override**: this map carries execution, not just decisions. Tickets
may build, deploy and migrate real services — the destination is a running
stack, not a spec.

**Adoption, not greenfield**: the *arr stack and friends already run on the box,
added by hand through unraid's Docker tab, with config and history to preserve.
Every migration ticket must adopt without data loss.

**Relationship to `~/home-ops`**: none. Different location, different household
site — no shared DNS, no shared domain, no cross-links, no coordination. It is a
reference for *taste* only: the SOPS habit, Renovate for image tags, and the
shape of the existing gethomepage config at
`kubernetes/apps/self-hosted/homepage/app/config/`.

**Box access**: ~~the unraid box is reached through its Web UI over tailscale, and
the human drives it. No SSH, no agent access to the host.~~ **Superseded
2026-08-02**: SSH is enabled and key-based agent access works
(`root@tower` over tailscale; public key persisted at
`/boot/config/ssh/root.pubkeys`, since unraid rebuilds `/root` from `/boot` each
boot). Box tickets no longer need a paste-back checklist.

**This does not relax caution — it tightens it.** The box's *only* other remote
path is the Unraid Web UI on **port 80 over tailscale**; 443 is bound to
localhost only. There is no out-of-band console, and the human has said a
lockout is a multi-day outage. So:

- State the rollback before any change touching port 80/443, docker networking,
  or tailscale on the box.
- **[15](issues/15-move-unraid-gui-ports.md) and [16](issues/16-deploy-caddy.md)
  are the live lockout risk** — Caddy wants the port the GUI's lifeline is on.
  Neither runs without a tested way back in.
- **Portainer is a second lifeline** (browser-reachable container control on
  :9000) until SSH has proven itself. Its removal under *Container scope* below
  waits on that, not just on adoption.

**Surface the hand-offs**: because Box access makes HITL routine, most tickets
end owing the human actions only they can perform. **Put them in their own
block at the very end of the session summary — never as a closing prose
paragraph.** One line each, starting with the verb, saying what stays broken
until it is done. A hand-off nobody notices silently stalls the map: 13's
Renovate config sat inert waiting on one click.

**Container scope**: git owns *all eight* workload containers, not just the five
the destination names — sonarr, radarr, prowlarr, qbittorrent, gluetun, plex,
calibre, lazylibrarian, plus a homepage that does not exist yet. No two-tier box
where some containers are git-owned and some stay on unraid's Docker tab.
Portainer is excluded as a workload, and [02](issues/02-choose-reconcile-mechanism.md)
has now settled its fate: **removed**, once its two stacks are adopted. Komodo's
own **four** containers take its place as the box's only non-workload tenants —
four, not three, since [11](issues/11-stand-up-komodo.md) put the database on
FerretDB-on-Postgres.
Three workloads have since been *added* by decisions rather than adopted from
the box: **Caddy** ([04](issues/04-reverse-proxy-and-domain.md)), **CoreDNS**
([05](issues/05-remote-access.md)) and **dockerproxy**
([08](issues/08-deploy-homepage.md)) — so the count is eight adopted, plus
homepage, Caddy, CoreDNS and dockerproxy built new. **Homepage and dockerproxy
are live**; the eight adopted are
[21](issues/21-migrate-arr-stacks.md)–[24](issues/24-migrate-download-stack.md).

**Default-private, explicit publish** ([05](issues/05-remote-access.md)): every
service is guarded to LAN + tailnet by default and **nothing is published to the
internet**. A service meant to face outward must declare it, conspicuously, in
its own file. Treat this as standing policy for any new service a ticket adds —
publishing is never a side effect.

**Secret severity**: the human has ruled these assets low-value — a NordVPN
*client* key (grants VPN egress as them, no access to the box, LAN or tailnet)
and a calibre GUI password on a LAN-only service. Both were already plaintext on
the box before this effort touched them. **Do not re-raise rotation as a blocker
or a finding.** Note the correction from
[03](issues/03-secrets-handling.md): this note previously claimed 03 would
re-issue the WireGuard key as a free side effect of picking a mechanism. It does
not — SOPS encrypts the existing value fine, so **rotation has not happened and
is not scheduled**. The ruling stands unchanged; only the false belief that it
came for free is removed. Two carve-outs stay live because they are about
*future*
exposure, not the current leak: auth in front of calibre's login, and if the
calibre password turns out to be reused elsewhere that is the human's call, made
outside this map. **Correction from [04](issues/04-reverse-proxy-and-domain.md)
and [05](issues/05-remote-access.md):** this note once said 04 *and* 05 would
decide that auth. Both declined, correctly — nothing is on the internet, so
there is nothing to defend. 05 removed the deadline rather than answering: auth
is now **fog**, live only once something is actually published. Do not expect a
ticket to be holding it.

**The layout is now in the repo, not the map**
([07](issues/07-repo-layout-and-conventions.md)): read
[CONTEXT.md](../../CONTEXT.md) for vocabulary,
[docs/repo-layout.md](../../docs/repo-layout.md) for the tree and its
conventions, and [docs/adding-a-service.md](../../docs/adding-a-service.md)
before any ticket that adds or migrates a service. Those three files are the
live artifact; this map only gists them. If a ticket finds the checklist needs a
*decision* rather than a keystroke, that is a defect in 07 — amend the doc and
say so on the ticket.

**Local tooling now exists** ([13](issues/13-local-tooling.md)): run
`mise install` once, then `just` to list the commands. The runner is **`just`**,
not go-task — do not reach for `task`. `just lint` is the gate every Stack must
pass and it also runs in CI. **The age key is real now**, so any ticket may write
a `secrets.sops.env` — always via `just secret <stack>`, never `sops --encrypt`
on a path outside the Stack directory, which finds no creation rule.

**Komodo is live** ([11](issues/11-stand-up-komodo.md)): v2.3.1 on
`http://192.168.1.195:9120`, Server `tower` connected, Stacks `plex` and
`download` adopted read-only. **Prefer Core's HTTP API to its UI** for anything
an agent drives — `POST /auth/login` with the admin credentials from
`/mnt/user/appdata/komodo/bootstrap/secrets.env` returns a JWT, and no call an
agent names can deploy by accident, where the UI keeps Deploy one mis-click
away. Credentials are `admin` plus a generated password in
[bootstrap/secrets.sops.env](../../bootstrap/secrets.sops.env) — **that file is
the source of truth and should stay it**; `KOMODO_INIT_ADMIN_*` is
create-if-absent (verified), so changing the password in the UI silently strands
the committed value and the rebuild story with it. Five wrong passwords lock the
account. Two facts every box ticket needs:
a `files_on_host` path must sit under `/mnt/user/appdata/komodo`, and **any
image running as a non-root uid needs its bind-mount target pre-created and
chowned** — Docker makes missing targets `root:root`, which crashlooped FerretDB
eight times.

**Never build an image on the box** ([12](issues/12-image-update-strategy.md)):
building our own images should be exceptionally rare, and when it is genuinely
needed it happens in **GitHub Actions**, pushed to GHCR — never on the box,
where a build competes with the thing running the deploys. Prefer a maintained
upstream image; 12 found one for Caddy, which was the only planned build. Every
image in the repo is `version@digest` with **no exceptions**, and Komodo's
`auto_update` is used nowhere.

**The loop is live** ([08](issues/08-deploy-homepage.md)): a Komodo Procedure
named `reconcile`, every 15 minutes, running `RunSync` **then**
`BatchDeployStackIfChanged` — a ResourceSync applies nothing by itself, it only
reports. Two rules every later ticket inherits: **the deploy pattern is an
explicit list of Stack names, never `*`** (a wildcard recreates the adopted
plex and download Stacks unattended), and **a Stack the pattern does not name is
never deployed**, which makes adding it a step of migrating. Drive it with
`just reconcile` rather than the UI or raw API calls, and `just bootstrap` to
recreate the ResourceSync on a rebuilt box — **no agent should be POSTing to
Core's API ad hoc**; if a new operation is needed, it goes in
[scripts/komodo.sh](../../scripts/komodo.sh) behind a recipe first.

**Skills to consult**: `/grilling` and `/domain-modeling` for the decision
tickets, `/research` for the AFK reading tickets, `/prototype` where a rough
concrete artifact would settle an argument faster than discussion.

### Settled while charting

- **Repo scope**: a general unraid GitOps repo, not a homepage-only one.
  Homepage is the proving case, but the conventions must generalise.
- **Reconcile scope**: git owns *container definitions* — image, tag, ports,
  volumes, env. A push recreates the container. Each service's own internal
  settings (sonarr's indexers, quality profiles, root folders) stay in its
  appdata database and are edited in its UI. Homepage is the exception: its
  config is plain YAML files, so git owns it fully.
- **Access**: reverse proxy on a real domain, qbittorrent behind a VPN, and
  remote access from outside the house. LAN-only IP:port was ruled out.
- **Tracker**: local markdown for now. The GitHub remote comes later, once
  enough investigation has landed to be worth pushing.

## Decisions so far

<!-- one line per resolved ticket -->

- [01 — Inventory the containers already running on the box](issues/01-inventory-running-containers.md)
  — the box as found, in [assets/01-inventory.md](assets/01-inventory.md).
  Unraid 7.3.2 / Docker 29.5.3 with **no compose on the host**; appdata
  `/mnt/user/appdata`, media `/mnt/user/Media`, LAN `192.168.1.195`, tailscale
  `tower`. Already two-tier: Portainer runs plex + gluetun/qbittorrent from
  compose, unraid's Docker tab runs the rest. The gluetun sidecar is **already
  in place**; provider is NordVPN, which has no port forwarding. PUID/PGID
  diverge three ways. Homepage does not exist at all.
- [02 — Choose the reconcile mechanism](issues/02-choose-reconcile-mechanism.md)
  — **Komodo**, as four containers on the box (Core, Periphery, and a
  Mongo-compatible DB which [11](issues/11-stand-up-komodo.md) settled as
  FerretDB-on-Postgres — two containers, not one); comparison in
  [assets/02-reconcile-mechanism.md](assets/02-reconcile-mechanism.md). Its
  Periphery image bundles compose and git, so the "no compose on the host"
  constraint is cleared without touching the host. Beat Portainer — a close,
  fairly-judged runner-up — because **ResourceSync puts Komodo's own config in
  git** and because `pre_deploy` is a real hook, which keeps SOPS alive for
  [03](issues/03-secrets-handling.md). **Portainer is removed** once its two
  stacks are adopted by compose project name. Reconcile is **poll** (cron
  `BatchDeployStackIfChanged`), not webhook — no inbound port exists yet.
- [03 — Decide how secrets live in the repo](issues/03-secrets-handling.md)
  — **SOPS + age**, encrypted in this repo, decrypted on the box by a Komodo
  `pre_deploy` hook writing `secrets.env` (a distinct name, so it does not
  clobber the `.env` Komodo generates itself). 02 over-priced this: **no custom
  Periphery image is needed** — the static `sops` binary is bind-mounted in,
  which also dodges the chicken-and-egg of rebuilding the container that runs
  your deploys. A **fresh** age key, not home-ops', at
  `/mnt/user/appdata/komodo/age.key` — deliberately **not** on `/boot`, which
  Unraid Connect ships off-site. Backed up in **KeePassXC over Syncthing**.
  Rebuild = clone + restore one key. Decrypted plaintext is left on the array on
  purpose; the defended boundary is directory perms, not the file. **`PLEX_CLAIM`
  leaves the secret set** (one-shot token, plex already claimed), leaving five
  live values.
- [04 — Choose the reverse proxy and the domain](issues/04-reverse-proxy-and-domain.md)
  — **Caddy** (`caddy-docker-proxy`, label-driven) on **`rbrb.in`**, DNS on
  **Cloudflare**, certs by **DNS-01 wildcard**. The domain is registered at
  **Gandi** with nameservers delegated to Cloudflare — no transfer, since DNS-01
  needs Cloudflare authoritative, not registrar. Traefik was reopened mid-grill
  (stock image, native DNS-01) and **declined on purpose**; Caddy's missing
  `caddy-dns/cloudflare` module was to be paid for by a **built image**
  — ~~an `xcaddy` Dockerfile in this repo, built on the box by a Komodo
  **Build** resource~~. **Overturned by [12](issues/12-image-update-strategy.md):
  nothing is built at all**, on the box or anywhere; a maintained upstream image
  is exactly this build. The acme.sh/lego
  "cert-manager shape" was tested and fails on two verified facts: Caddy does
  not watch cert files on disk, and acme.sh's docker deploy hook is broken in
  daemon mode. Hostnames are **one namespace, LAN-pointed** — `*.rbrb.in` → A
  `192.168.1.195`, **grey cloud**; services are **LAN-only for now** and
  split-horizon is deferred. Adds a **sixth live secret**: a zone-scoped
  Cloudflare DNS-edit token.
- [05 — Decide the remote access approach](issues/05-remote-access.md)
  — **split-horizon after all, built now**, because 04 over-priced it:
  Cloudflare's public record *already is* the LAN view, so only the tailnet half
  needs overriding — one container, no router or DHCP change. **CoreDNS** (stock
  image, Corefile in git, no state) answers `*.rbrb.in` → `100.126.56.26`, bound
  to **`100.126.56.26:53` only** to dodge `tailscaled`'s `100.100.100.100:53` and
  stay off the LAN. **Tailscale Split DNS** points `rbrb.in` at it; **MagicDNS is
  a hard prerequisite**, and there is no static-record alternative. A subnet
  router was declined (silently shadowed by any remote `192.168.1.0/24`), as was
  pointing the wildcard at the tailnet IP (breaks non-tailnet household
  devices). **Nothing is published** — plex reaches the outside on its own
  `32400` path, bypassing Caddy entirely — but everything is built as if it will
  be: **default-deny to LAN + tailnet on every service**, publishing an explicit
  per-service opt-in. Auth was **not** settled; it went back to the fog. No new
  secrets.

- [06 — Decide the qbittorrent VPN topology](issues/06-qbittorrent-vpn-topology.md)
  — **topology adopted unchanged** (gluetun sidecar); findings in
  [assets/06-vpn-topology.md](assets/06-vpn-topology.md). **Only qbittorrent's
  torrent-*related* traffic is tunnelled** — every service UI and all other HTTP stays
  ordinary LAN/tailnet traffic, which the current setup already does. Treat this
  as a constraint to preserve on any change to the stack; tracker announces are
  the one HTTP flow that is tunnelled, correctly. **NordVPN stays and
  port forwarding is not being bought** — qbittorrent is knowingly leech-only,
  a settled posture, not a defect. The two firewall env vars are **not gluetun
  variables at all** and are **dropped, not corrected**: spelling
  `FIREWALL_OUTBOUND_SUBNETS=0.0.0.0/0` properly would let all traffic bypass
  the tunnel, so the typo is the only reason the kill switch still holds. The
  kill switch is otherwise sound — qbittorrent has no interface of its own, and
  `HEALTH_RESTART_VPN` restarts the VPN *process*, not the container. **New
  hazard**: recreating gluetun orphans qbittorrent in a dead namespace, silently
  — which GitOps makes routine, since any push touching gluetun recreates it.
  The *arr move to a **shared user-defined network**, addressed
  `http://gluetun:30024` (the namespace owner resolves, not `qbittorrent`),
  which takes the box's LAN address out of git. No new secrets.

- [07 — Decide the repo layout and per-service conventions](issues/07-repo-layout-and-conventions.md)
  — the answer is three files in the repo itself:
  [CONTEXT.md](../../CONTEXT.md) (vocabulary),
  [docs/repo-layout.md](../../docs/repo-layout.md) and
  [docs/adding-a-service.md](../../docs/adding-a-service.md). **The atom is a
  Stack** — one directory under `stacks/` holding *both* its compose file and its
  Komodo TOML, so adding a service is copying a directory. Komodo's own noun, and
  it admits the one multi-container unit: `download` (gluetun + qbittorrent),
  because `network_mode: service:` cannot cross compose projects. **Flat tree, no
  infra/apps tiers**, plus a deliberate `bootstrap/` holding Komodo's own compose
  — in git for the rebuild story, never reconciled, since Komodo cannot deploy
  itself. Shared config is **`common.env` at the root** via
  `additional_env_files` (**not** mise, which never runs on the box; **verify on
  the box** that a relative path escaping the run directory resolves). **One
  network, `shared`** — 06's two needs do collapse — created idempotently by
  **every** Stack's `pre_deploy`, which also makes `pre_deploy` uniform. Caddy
  globals live in a **bind-mounted `Caddyfile`**. **Default-deny is enforced by
  `scripts/check-exposure.sh`**, not left to the checklist: a `caddy:` hostname
  requires either `caddy.import: internal` or an explicit `x-published: true`,
  which doubles as the grep for what faces the internet. Images pin **version +
  digest in one string** (`:4.0.19.2995@sha256:…`), the verified home-ops
  convention — locally built Caddy is the sole bare-tag exception. No new secrets.

- [09 — Unify PUID/PGID/UMASK, and decide what happens to files already written](issues/09-unify-uid-gid.md)
  — **99:100 everywhere, no exceptions**, `UMASK=002`, `TZ=America/Vancouver`,
  written to [common.env](../../common.env). 99:100 because it is what the
  *rest of the box* writes as (SMB, the file manager, Docker Safe New Perms),
  not merely the container majority; plex was offered an exception to skip a 20G
  chown and it was **declined**. **The media binds do not move.** A TRaSH-style
  single `${MEDIA}` → `/media` mount was decided and then **reversed on
  evidence**: the array is six XFS disks under shfs holding a 39.1 TB library,
  so a download and its destination share a physical disk only by chance
  (~1 in 6), and hardlinks cannot cross filesystems — the move would have cost
  stored-path surgery in five databases (including plex's, with `Plex SQLite`)
  and bought a coin flip. **Hardlinks and single-mount are now out of scope.**
  Files on disk are fixed by **one big-bang chown window**, everything stopped —
  raised as [20 — Chown the tree to 99:100](issues/20-chown-to-99-100.md), which
  must run before plex, gluetun or qbittorrent adopt. Because no path changes,
  **adoption order is otherwise unconstrained**. New risk: plex drops to uid 99
  and `/dev/dri` access is group-dependent, so hardware transcoding is a check,
  not an assumption. No new secrets.

- [10 — Publish the repo to a remote the box can reach](issues/10-publish-repo-to-remote.md)
  — **`https://github.com/Nospamas/unraid-ops`, public, cloned anonymously.
  There is no credential.** The ticket was written expecting private and
  therefore expecting to house a *bootstrap secret* — the one token that cannot
  live in the repo it unlocks; public dissolves that question entirely, so
  `bootstrap/compose.yaml` stays clean and 03's rebuild story stays **clone +
  restore one age key**. The case against public was put and **withdrawn on
  evidence**: `home-ops` is itself public and already commits
  `cloudflare-tunnel` and `external-dns-cloudflare` ciphertext — the same class
  as 04's Cloudflare token — so public + SOPS is a settled habit here, not a
  fresh exposure. **Do not re-raise visibility.** All of `.scratch/` ships, and
  **history was published as-is**: a sweep of all ten commits found no key
  material (the only high-entropy strings are image digests) and confirmed 01's
  on-box redaction held, so nothing needed rewriting. `master` → `main` before
  the first push. Two facts went to [11](issues/11-stand-up-komodo.md) —
  whether Komodo accepts a Stack with **no `git_account`** (unverified; if it
  does not, the bootstrap-secret question returns) and whether the box has
  outbound HTTPS to github.com. Makes [12](issues/12-image-update-strategy.md)
  cheaper: Renovate and Actions are free on public repos. No new secrets.

- [13 — Decide the local tooling and task runner](issues/13-local-tooling.md)
  — **`just`, not go-task**; go-task is not pinned at all. The recommendation put
  was go-task on symmetry-with-home-ops grounds and it was **declined on merit**.
  Eight tools pinned in [.mise.toml](../../.mise.toml) via `aqua:` — `just`,
  `age`, `sops`, `hadolint`, `jq`, `shellcheck`, `yq`, plus `gh` as the sole
  `latest`; docker is not pinned (system daemon). Four recipes in
  [justfile](../../justfile): `default`, `secret <stack>`, `lint`,
  `verify-secrets`. **The biggest find: 03's age keypair had never been
  generated**, so `.sops.yaml` could not exist and 08, 14 and `download` were
  silently blocked on a step no ticket owned — 13 took it, and the recipient is
  now committed in [.sops.yaml](../../.sops.yaml) with the private key gitignored
  at the repo root. Round-trip verified. **`scripts/check-exposure.sh` was
  written, not merely wired** — and its first version *failed open*, printing
  `exposure ok` over files it could not parse, which is now fatal; it reads both
  compose label forms, and declaring `internal` **and** `x-published` is a
  failure. Verified against seven fixtures. `.renovaterc.json5` (home-ops'
  filename, not `renovate.json`) covers mise + github-actions only; 12 extends.
  CI is `just lint` on push and PR, **touching no secrets**. A `reconcile` recipe
  was **declined** — it needs a Komodo API key on the laptop, a second local
  secret, to skip a poll the web UI already short-circuits. Two 07 doc defects
  amended, including an `adding-a-service.md` sops command that **could not have
  worked**: SOPS matches creation rules against the *input* path. Scope was
  widened by the human to sweep in all general repo tooling, hence the dotfiles,
  CI and README. **All three hand-offs are done**: Renovate is live and reading
  the config ([dashboard #1](https://github.com/Nospamas/unraid-ops/issues/1)),
  `age.key` is in KeePassXC, and the key is on the box at
  `/mnt/user/appdata/komodo/age.key` — though **nothing has decrypted with the
  box copy yet**, which [11](issues/11-stand-up-komodo.md) carries. Placing it
  also produced the first look at appdata permissions — **777**, recorded on
  [19](issues/19-secret-hygiene-on-the-box.md). No new secrets — `age.key` is
  03's root secret finally instantiated, not an addition.

- [11 — Stand Komodo up on the box](issues/11-stand-up-komodo.md)
  — **Komodo v2.3.1 is running and reconciling nothing, exactly as intended**;
  bootstrap in [bootstrap/](../../bootstrap/), checklist in
  [assets/11-bootstrap-checklist.md](assets/11-bootstrap-checklist.md). Four
  containers, not three: the database is **FerretDB-on-Postgres, not MongoDB** —
  Mongo came up fine (AVX present) and was torn down anyway, because the human
  already runs Postgres and backs it up with `pg_dump`, which is a better reason
  than the one the committed plan was built on. Cost nothing: 203 MB of fresh
  install. **02 researched v1.18.0 and v2 shipped two days before this session** —
  passkeys are gone (Core and Periphery auto-generate a keypair), **Periphery
  dials Core** so it needs no inbound port, and `:latest` is deprecated. Every
  field the map rests on survives v2. 02 also walked past a chicken-and-egg — the
  bootstrap must deploy the container that carries compose — resolved by running
  **the Periphery image itself as a compose CLI**. All four open risks closed
  green: Periphery bundles Compose v5.3.1, `../../common.env` resolves from a
  Stack directory, `docker network create` works from `pre_deploy` (`shared`
  exists), and **the box's `age.key` decrypts** — 13 placed it, this proved it.
  Periphery sees all 12 containers. **Adoption by `project_name` works**: Stacks
  `plex` and `download` match the live containers read-only, with no deploy —
  but only after a silent failure taught the general rule that **a
  `files_on_host` path must live under `PERIPHERY_ROOT_DIRECTORY`**, so the
  compose files were copied to `/mnt/user/appdata/komodo/adopt/`. **`git_account`
  empty clones the public repo** — 10's loud question answered, no token exists.
  Two warnings: Komodo **mis-reports a `container:` sidecar's network**, so
  06's silent-orphan hazard cannot be seen from the UI; and Core's API takes the
  **admin password** directly at `POST /auth/login`, no API key — which reopens
  13's reason for declining a `reconcile` recipe. Box upgraded mid-ticket to
  Unraid 7.3.2 / Docker 29.5.3; **still no compose on the host**, so 02's whole
  premise holds. New secrets: four, all **high-value and outside the map's
  Secret severity ruling** — `KOMODO_JWT_SECRET`, `KOMODO_DATABASE_PASSWORD`,
  `KOMODO_WEBHOOK_SECRET`, admin password — decrypted **by hand, once**, since
  the thing that runs `pre_deploy` is what is being installed.

- [12 — Decide the image update strategy](issues/12-image-update-strategy.md)
  — **Renovate, and only Renovate**; rules landed in
  [.renovaterc.json5](../../.renovaterc.json5), extending 13's file. 07's reading
  confirmed *and* made structural: `auto_update`/`poll_for_updates` are used
  nowhere and **could not be**, since a `version@digest` pin cannot drift.
  Minor+patch automerge on the weekend schedule, with four human-merge carve-outs
  where a bad version is expensive and **monitoring is still fog** — `download`
  (06's silent-orphan hazard, still unverified), `plex`, `caddy`, `coredns`.
  **One PR per Stack directory**, which needed exactly one group rule because
  only `download` holds two images. **Bootstrap is deliberately not GitOps'd and
  never gets a `komodo.toml`**: Core *can* redeploy itself, but **Periphery
  cannot**, and upstream requires the two match versions — so the automatable
  half is chained to the manual half. Renovate raises pair-grouped PRs
  (`komodo`, `ferretdb`), the human merges **then** applies over SSH; apply-then-
  merge was put and declined, and the resulting window where `main` is ahead of
  the box is covered by `prBodyNotes` rather than a drift-check recipe.
  **The biggest change: Caddy is no longer built — nothing is.** The human's
  standing rule (build rarely, and in Actions, never on the box) sent 04's
  `xcaddy` plan back; four prebuilt candidates were evaluated and
  **`ghcr.io/serfriz/caddy-cloudflare-dockerproxy`** adopted — 334★, auto-built
  per Caddy release, and its Dockerfile is byte-for-byte the build we'd have
  written. The other three failed on missing `docker-proxy`, a dead repo, or
  `latest`-only tags. So **07's bare-tag exception is deleted, not narrowed**,
  16 loses its Dockerfile and `[[build]]`, and the Procedure needs no build
  stage; the four-line Dockerfile is kept on 12 as the escape hatch. **Nothing is
  verified against a live Renovate run** — `stacks/` is still empty, so these
  rules are written ahead of the files they match and 08 is their first test.
  No new secrets.

- [08 — Deploy homepage from the repo](issues/08-deploy-homepage.md)
  — **the loop is real: a push changed the box in 8m34s, unattended**, on a
  commit touching only `config/bookmarks.yaml`. Two Stacks landed —
  `stacks/homepage/` and `stacks/dockerproxy/` — plus the reconcile Procedure in
  [komodo/](../../komodo/). The loop is **two stages, not one**: a ResourceSync
  *applies nothing on its own* (Core only reports pending changes), so `RunSync`
  runs first and `BatchDeployStackIfChanged` second, on a 15-minute cron.
  **That pattern is an explicit list of Stack names and must never be `*`** — an
  adopted-but-never-deployed Stack has no deployed contents to diff, which
  Komodo reads as *deploy it*, so a wildcard would recreate plex and the
  gluetun/qbittorrent pair on a timer. Adding a Stack to that line is now part
  of migrating it. 07's checklist had **three defects**, all fixed in the docs:
  config files a service reads must be listed in `config_files` or a config push
  is silently inert; `secrets.env` goes in compose's `env_file` (with
  `required: false`), because `additional_env_files` **tracks** its entries
  against a repo the file is deliberately absent from; and the deploy pattern is
  a per-Stack step. Homepage runs as **uid 99 with no exception to 09**, but
  `/app/config` must be **writable** — it seeds missing skeleton files and 500s
  otherwise — so the repo ships all nine and the clone stays clean. Its appdata
  is logs and nothing else. The docker socket was **not** given to homepage
  (upstream requires root for that): `dockerproxy` holds it read-only on **its
  own `--internal` network**, which corrects 07's one-network rule — `shared` is
  for what Caddy must reach, a privileged API is for exactly one consumer.
  **`just bootstrap` and `just reconcile` now exist**, and step 8 of
  [bootstrap/README.md](../../bootstrap/README.md) with them: the ResourceSync
  is the one resource a sync cannot create, and it was briefly living only in a
  session transcript. That **reverses 13's decline of a reconcile recipe** —
  11 found Core takes the admin password directly, so the second local secret 13
  refused to pay for does not exist. Four new secrets (three *arr keys and
  plex's account-scoped token), piped from the box into SOPS without ever
  touching disk in plaintext.

- [14 — Set up the rbrb.in zone on Cloudflare and mint the DNS token](issues/14-cloudflare-zone-and-token.md)
  — **the zone is live and the sixth secret exists**: `rbrb.in` active on
  Cloudflare (`corey`/`pearl.ns.cloudflare.com`, registrar still Gandi),
  `*.rbrb.in` → A `192.168.1.195` **grey cloud**, and a zone-scoped token
  encrypted at
  [stacks/caddy/secrets.sops.env](../../stacks/caddy/secrets.sops.env) as
  `CLOUDFLARE_API_TOKEN`. Verified against **Cloudflare's API, not its UI**:
  token `active`, `GET /zones` returns exactly one zone (the
  scoping is real), and the `?name=` lookup succeeds. **The ticket's own
  instructions were wrong twice.** It named one permission and one is not
  enough — `libdns/cloudflare` resolves the zone ID via `GET /zones?name=`
  before writing `_acme-challenge`, so **`Zone / Zone / Read` is required
  alongside `Zone / DNS / Edit`**; followed literally,
  [16](issues/16-deploy-caddy.md) would have failed at *lookup*, an error that
  reads like a Caddy fault. And the zone was **not blank** — Gandi's
  fresh-domain defaults imported on the scan, two of them orange-clouded. The
  apex `A` and `www` CNAME were deleted; the **Gandi mail set was deliberately
  kept** (MX, SPF, five SRV, `webmail`), so mail on `rbrb.in` still works. Two
  facts for 16: **`webmail.rbrb.in` is a reserved hostname** — a real *proxied*
  record, so it does not fall through the wildcard and Caddy can never own it —
  and **the apex has no `A` at all**, since a wildcard never covers the apex.
  The token arrived **untracked** and was encrypted in place, so no plaintext
  ever entered git. `stacks/caddy/` now holds *only* the secret; 16 adds the
  rest, and `just lint` tolerates the compose-less directory.

## Not yet specified

- **Reconciling on push rather than on a timer.** The loop polls every 15
  minutes because nothing inbound reaches the box
  ([02](issues/02-choose-reconcile-mechanism.md)), and
  [08](issues/08-deploy-homepage.md) built it that way knowingly — Komodo
  supports git webhooks, and Core already generates a `KOMODO_WEBHOOK_SECRET`
  and shows `webhook_enabled: true` on the Procedure. Fog because the trigger
  has not fired: a webhook needs GitHub to reach Core, and **nothing is
  published** ([05](issues/05-remote-access.md)). It becomes sharp the moment
  [16](issues/16-deploy-caddy.md) lands and something decides whether Komodo is
  the first service worth publishing — which is a *scope* question about
  default-private, not just a plumbing one. Until then 15 minutes is the answer,
  and the poll is not a defect to be fixed in passing.
- **Appdata backup and box rebuild.** Once container definitions are in git, the
  remaining single point of failure is appdata — 24G of it, dominated by plex's
  20G. Ticket 02 added to the pile: Komodo's own database is new off-git state,
  and it holds the resource records and any Variables-based secrets. What backs
  all this up, and what a rebuild-from-scratch actually takes, is unclear until
  the layout exists.
- **Authentication in front of the services.** The map twice expected a ticket to
  settle what sits in front of calibre's login and qbittorrent's WebUI; 04 and
  then [05](issues/05-remote-access.md) both declined, because with nothing
  published there is nothing to defend. 05 built the **gate** — default-deny to
  LAN + tailnet, publishing an explicit opt-in — but deliberately not the
  defence. Fog because the trigger has not fired. It becomes sharp the moment
  either is true: **a service is actually published** (the human named a future
  status page as the likely first), or **the LAN stops being trusted** — guest
  wifi or IoT on `192.168.1.0/24` would do it. Until then there is nothing to
  decide, and no ticket should be opened for it.
- **Whether the LAN half of split-horizon ever needs its own resolver.**
  [05](issues/05-remote-access.md) leans on Cloudflare's public record *being*
  the LAN view, which works precisely because nothing is published. If a
  forwarded port is ever wanted, the wildcard must point at the public IP and
  the LAN view needs somewhere else to come from — either hairpin NAT or a
  second CoreDNS view. Fog, and it stays fog unless publishing happens; noted so
  the coupling is not rediscovered the hard way.
- **Monitoring and alerting** for the stack. Suspected, unsharp; may fall out of
  scope entirely once the stack is running.
  [08](issues/08-deploy-homepage.md) has moved this from hypothetical to
  observed: the box now changes on a timer with nobody watching, and the only
  thing that noticed the first unattended deploy was a person who happened to be
  looking. Komodo's `schedule_alert` is off on `reconcile` (four runs an hour is
  noise) and `failure_alert` is on with **no alerter configured to receive it** —
  so a failing reconcile is currently silent. That is the sharpest single thing
  here.
  [12](issues/12-image-update-strategy.md) has given it a **trigger** without
  making it sharp: minor+patch image bumps automerge and deploy unattended on the
  next poll, so from the first Stack onward the box can change with nobody
  watching. 12 bought time by carving the expensive services out to human merge —
  `download`, `plex`, `caddy`, `coredns` — but that carve-out *is* the stand-in
  for monitoring, and it should be revisited the moment something is watching.
  Komodo has its own alerters, which is the obvious first place to look.

## Out of scope

- **Decommissioning or migrating `~/home-ops`.** The k8s cluster is a different
  site and stays as it is. If it is ever retired, that is a fresh effort with
  its own destination.
- **Unraid array, share and disk configuration.** This map governs containers
  and their config, not the storage layer underneath them.
- **Hardlinked imports, and the single `/media` mount that would enable them**
  ([09](issues/09-unify-uid-gid.md)). Out of scope on capability, not on
  sharpness: `git push` reconciling the box does not require them, and on this
  array they cannot reliably work — six XFS disks under shfs, a 39.1 TB library,
  and hardlinks that cannot cross filesystems. Making them viable means
  restructuring the share layout, which is the storage layer ruled out above.
  A fresh effort if it is ever wanted; **not** a tidy-up someone should do in
  passing, which is why [docs/repo-layout.md](../../docs/repo-layout.md) says so
  at the binds themselves.
