# 11 — Stand Komodo up on the box

Type: task (HITL)
Status: closed
Assignee: Nospamas
Blocked by: 10

## Question

Surfaced by [02](02-choose-reconcile-mechanism.md). Choosing the mechanism does
not install it — and installing it is substantial enough, and enough of a
hand-off, that folding it into [08](08-deploy-homepage.md) would muddy what the
proving case proves. 08 should prove *the reconcile loop*, not *the install*.

Get Komodo running and reconciling nothing, then confirm it can see what is
already there.

Do:

- **Install the three containers**: `komodo-core`, a Mongo-compatible database
  (MongoDB, or FerretDB-on-Postgres — Postgres and SQLite are not directly
  supported as of v1.18.0), and `komodo-periphery`. ~~Periphery has a Community
  Apps entry, so it installs the ordinary unraid way~~ — superseded, see
  *Findings* below: all three go up from one compose file instead. Core and the
  database need standing up too, and until Komodo exists there is nothing to
  deploy them *with* — so this bootstrap step is by hand, and it is the last
  thing on the box that will be.
- **Get `PERIPHERY_ROOT_DIRECTORY` right.** Per 02 it must be an *identical*
  path inside and outside the container or stack path resolution breaks — mount
  `/mnt/user/appdata/komodo:/mnt/user/appdata/komodo`, not the usual
  `:/etc/komodo`. This is the single most likely thing to go wrong.
- **Point Core at the remote** from [10](10-publish-repo-to-remote.md) —
  `https://github.com/Nospamas/unraid-ops`, **public, no credential**. See the
  section 10 added below before configuring a git account.
- **Confirm Periphery sees the host's containers** — all eight workloads plus
  Portainer should appear. This is the check that the docker socket mount and
  ~~the passkey handshake~~ the Core/Periphery keypair are right. Passkeys are
  gone in v2; see *Findings*.
- **Adopt the two Portainer stacks read-only first**: create Stacks with
  `project_name` set to the existing Portainer project names (`docker compose
  ls` on the box gives the exact names) and `files_on_host` pointing at
  `/mnt/user/appdata/portainer/compose/`. Confirm Komodo shows them as healthy
  and matched **without deploying them**. This proves adoption-by-project-name
  works before anything moves into the repo. Moving those files into the repo
  is [07](07-repo-layout-and-conventions.md)'s layout and a later migration, not
  this ticket.
- **Do not remove Portainer.** 02 rules it removed only once every workload
  reconciles from the repo.

Note the version of Komodo installed, so later tickets can check behaviour
against the right docs.

**HITL**: everything here touches the box, so it runs as a hand-off checklist
per the map's Box access note — commands to run in the Web UI terminal, output
pasted back.

The answer records what is running, on which ports, where its appdata lives,
the Komodo version, whether Periphery saw all the containers, and whether the
two Portainer stacks matched by project name.

## Added by [07](07-repo-layout-and-conventions.md)

Two things to establish while the box is in hand, both cheap here and expensive
to discover later:

- **Verify that `additional_env_files` resolves a relative path escaping the run
  directory** — 07's shared config depends on
  `additional_env_files = ["../../common.env"]` from `stacks/<name>/`, and this
  has not been tested. If it does not resolve, the fallback is a symlink per
  Stack; report which.
- **Record the exact Portainer compose project names** (`docker compose ls`).
  07 requires every `[[stack]]` to set `project_name` explicitly, and for plex,
  gluetun and qbittorrent it must match what already exists or Komodo stands up a
  second copy beside the running one instead of adopting it.

Also worth confirming while there: that the Periphery image's bundled `docker`
CLI can run `docker network create` from a `pre_deploy` — 07 puts an idempotent
create in **every** Stack's `pre_deploy` as the way the `shared` network comes
into existence.

## Added by [10](10-publish-repo-to-remote.md)

The remote is live: `https://github.com/Nospamas/unraid-ops`, **public**, default
branch `main`. Anonymous HTTPS clone is verified working from the workstation
with credentials explicitly disabled — so **there is no token to configure**, and
10 deliberately created none.

Two things to settle here that 10 could not settle off-box:

- **Whether Komodo accepts a Stack with no `git_account` set.** The docs read as
  though it is optional for public repos, but this is **unverified**. Leave
  `git_account` empty and see whether the clone succeeds. **If it turns out to be
  mandatory even for anonymous clones, say so loudly** — that resurrects the
  bootstrap-secret problem 10 dissolved (a credential that unlocks the repo
  cannot live in the repo), and it needs a deliberate answer, not a quietly
  minted token.
- **Confirm the box has outbound HTTPS to github.com.** Folded in here rather
  than run as a separate hand-off, since 11 is already a box session and the
  first ResourceSync proves it better than a standalone clone would:

  ```
  curl -sI https://github.com/Nospamas/unraid-ops | head -1
  git clone --depth 1 https://github.com/Nospamas/unraid-ops /tmp/rt && \
    ls /tmp/rt && rm -rf /tmp/rt
  ```

  Expect `HTTP/2 200` and a tree containing `docs/`, `CONTEXT.md`,
  `common.env`. No credential prompt should appear; if one does, the repo is not
  public — stop and check.

## Added by [13](13-local-tooling.md)

**The age key now exists.** 03 decided it; 13 generated it. Recipient
`age1pj9c9wur8s7h7ynfh0pqxwvkd70hzvq92hvds4t5w0xfa5p83ggqfx5k25`, committed in
[.sops.yaml](../../../.sops.yaml); the private half is at `age.key` in the repo
root on the workstation, gitignored.

One more thing to do while the box is in hand — the second of the key's three
copies per [03](03-secrets-handling.md):

- **Place the private key at `/mnt/user/appdata/komodo/age.key`, mode 600**, and
  bind-mount it read-only into Periphery beside the `sops` binary. Deliberately
  **not** on `/boot`, which Unraid Connect ships off-site. The human transfers it;
  do not paste it into a Web UI terminal if that can be avoided, and if it is
  pasted, remember the value is then in browser scrollback.
- **Confirm `sops --decrypt` works from inside Periphery** with that key mounted,
  before any Stack's `pre_deploy` depends on it. `just verify-secrets` proves the
  laptop copy; nothing yet proves the box copy.

## Findings (2026-08-02, off-box half done)

The AFK half of this ticket is done: the artifacts exist and the facts that
could be settled without the box are settled. What remains is the box itself,
handed off as
[assets/11-bootstrap-checklist.md](../assets/11-bootstrap-checklist.md).
**This ticket stays open until that output comes back.**

### Komodo is on v2 now, and [02](02-choose-reconcile-mechanism.md) researched v1

**v2.3.1, released 2026-07-31** — two days before this session. 02's asset was
written against **v1.18.0**, so parts of it and parts of this ticket's own
checklist described a version that no longer ships. What changed that matters
here:

- **Passkeys are gone.** Core and Periphery auto-generate a keypair and rotate
  it; the shared `/config/keys` directory is the whole handshake. There is
  nothing to paste, which removes the fiddliest step this ticket anticipated.
- **Periphery dials Core**, not the reverse (`PERIPHERY_CORE_ADDRESS`). It
  needs no inbound port and no address on the LAN.
- **`:latest` is deprecated**; v2 images are only published under `:2`.
- **The Community Apps route is dropped.** It exists to install Periphery
  alone, which made sense when Periphery was the inbound half. With all three
  containers in one compose file sharing one keys directory, a CA install is a
  second, divergent source of truth for one of them.

What did **not** change, verified in `client/core/rs/src/entities/stack.rs` on
`main`: `pre_deploy`, `post_deploy`, `project_name`, `additional_env_files`,
`files_on_host`, `git_account`, `webhook_enabled`. Every field the map's
decisions rest on survives v2. Database support also did not change — Mongo or
FerretDB-on-Postgres, nothing else.

### [10](10-publish-repo-to-remote.md)'s `git_account` question is answered

10 asked this to be verified loudly because a "no" resurrects the bootstrap
secret it dissolved. The answer is **yes, empty is supported**, and it comes
from the struct's own doc comment rather than from docs prose:

> `git_account`: "The git account used to access private repos. **Passing empty
> string can only clone public repos.**"

Still worth confirming empirically — it is in the checklist — but the alarm 10
asked for is not needed.

### The bootstrap has its own chicken-and-egg, and 02 walked past it

02 chose Komodo *because* Periphery carries compose, so the host does not need
it. But the bootstrap has to deploy the container that carries compose, using a
compose the host does not have. Nothing in the map had noticed.

The way out is that **the Periphery image is a compose implementation you can
run before you install it**:

```sh
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/user/appdata/komodo:/mnt/user/appdata/komodo \
  -w /mnt/user/appdata/komodo/bootstrap \
  --entrypoint docker ghcr.io/moghtech/komodo-periphery:2.3.1 compose -p komodo
```

Portainer is the fallback — it embeds compose and is still on the box — but it
is second choice on purpose: it would put Komodo's secrets in the database of
the tool 02 is retiring, and it would leave the rebuild story depending on a
container that will not exist. **Unverified until block 4 of the checklist
runs**; if it fails, the fallback is real and
[bootstrap/README.md](../../../bootstrap/README.md) needs amending.

### Komodo brings genuinely high-value secrets, unlike the two the map has ruled on

The map's **Secret severity** note rules the NordVPN key and the calibre
password low-value. **These are not in that class and the note must not be read
as covering them**: `KOMODO_JWT_SECRET` signs Komodo's own sessions and Core
answers on the LAN, so leaking it is full control of every container on the
box. `KOMODO_DATABASE_PASSWORD`, `KOMODO_WEBHOOK_SECRET` and the initial admin
password join it.

They cannot follow the usual route — every other Stack decrypts in a Komodo
`pre_deploy`, and the thing that runs `pre_deploy` is what is being installed.
So `bootstrap/secrets.sops.env` is committed encrypted under the existing
creation rule and **decrypted by hand, once**, during bootstrap. Values are
generated and already committed; `just secret bootstrap` reads them.

This is a small widening of 13's tooling: `just secret` now accepts `bootstrap`
as well as a Stack name, `just verify-secrets` covers it, and `just lint`
validates `bootstrap/compose.yaml` against `bootstrap/compose.env`.

### Two corrections to upstream's compose, for this box specifically

- **Mongo's data is a bind mount, not a named volume.** Upstream uses
  `mongo-data:`/`mongo-config:`, which land in `docker.img` — a file Unraid
  users recreate routinely, and which holds every Komodo resource record. Bound
  to `/mnt/user/appdata/komodo/mongo` instead. The `keys` volume moves for the
  same reason: losing it loses the Core/Periphery keypair.
- **`KOMODO_RESOURCE_POLL_INTERVAL: 5-min`**, not the 1-hr default. An hour
  between `git push` and reconcile is a poor read on the destination.
  [08](08-deploy-homepage.md) may want to revisit it once the loop is real.

### Artifacts written

- [bootstrap/compose.yaml](../../../bootstrap/compose.yaml) — all three
  containers, images pinned version + digest per
  [07](07-repo-layout-and-conventions.md) (`komodo-core:2.3.1`,
  `komodo-periphery:2.3.1`, `mongo:8.0`).
- [bootstrap/compose.env](../../../bootstrap/compose.env) — non-secret config.
  `KOMODO_FIRST_SERVER_NAME=tower` is the Server name `komodo/sync.toml` will
  reference.
- [bootstrap/secrets.sops.env](../../../bootstrap/secrets.sops.env) — encrypted.
- [bootstrap/README.md](../../../bootstrap/README.md) — the run order, the sops
  binary's version and sha256 as [03](03-secrets-handling.md) required, and the
  rebuild path.
- [docs/repo-layout.md](../../../docs/repo-layout.md) — the tree now lists the
  bootstrap env files, and states the by-hand-decrypt exception.

### Open risks the checklist has to settle

- **MongoDB 8 requires AVX**, and no ticket has recorded this box's CPU.
  Block 1 checks it; the fallback is FerretDB-on-Postgres, which is exactly why
  Komodo offers it.
- Whether the Periphery image's `docker compose` runs standalone (above).
- Whether `additional_env_files` resolves `../../common.env` — 07's unverified
  assumption. Block 5 gives the cheap answer; 08 gives the real one.
- Whether the box's copy of `age.key` decrypts. 13 placed it; **nothing has
  used it yet**. Block 3 is the first real test.

## Findings (2026-08-02, on-box half — blocks 1–5 run)

**Komodo v2.3.1 is up and Periphery is connected.** Run over SSH rather than as
a paste-back checklist: the human enabled SSH this session, so the map's *Box
access* note is superseded. All four open risks above are settled, all green.

### Every open risk, closed

| Risk | Answer |
|---|---|
| MongoDB 8 needs AVX | **present** — Ryzen 7 3700X. Moot; see below. |
| Periphery image runs compose standalone | **yes** — bundles Compose **v5.3.1** |
| `additional_env_files` escapes the run dir | **yes** — `../../common.env` resolved |
| Box `age.key` decrypts | **yes** — 6 keys, and again from *inside* Periphery |

### The database is FerretDB-on-Postgres, not MongoDB

This ticket's artifacts specified Mongo and treated FerretDB purely as the
*fallback if AVX were missing*. AVX is present, so the bootstrap ran as written
and Mongo came up — at which point the human said they would have preferred
FerretDB, **because they already run Postgres and back it up with `pg_dump`**.

That is a better reason than the one the artifacts were built on, and the switch
was free: the Mongo database was 203 MB of a fresh install — the seeded admin
and Komodo's initial system resources, no Stacks, no history. Torn down,
discarded, redeployed on FerretDB. `KOMODO_INIT_ADMIN_*` re-seeded the admin.

**The lesson for the map**: standing up a database is a decision worth surfacing
even when a committed plan already names one. AVX was the only question the
checklist thought to ask, and it was the wrong one.

Pinned as a matched pair, because the Postgres image tag names the FerretDB
release it was built against and upstream warns updates can break:

- `ghcr.io/ferretdb/postgres-documentdb:17-0.107.0-ferretdb-2.7.0`
- `ghcr.io/ferretdb/ferretdb:2.7.0`

Two adaptations to upstream's `ferretdb.compose.yaml`:

- **Postgres data lives on `/mnt/cache/appdata`, not `/mnt/user`** — the only
  path in the file that does. appdata is `shareUseCache="only"`, so both names
  reach the same files on the nvme, but `/mnt/user` goes through shfs (FUSE) and
  a database should not write WAL through it.
- **`komodo.skip: ""` on both**, as upstream does — it stops Komodo halting its
  own database on *StopAllContainers*.

`pg_dump` against `komodo-postgres` works: 1863 schema lines. Neither 27017 nor
5432 is published.

**A bind-mount trap worth remembering.** FerretDB crashlooped 8 times on
`open /state/state.json: permission denied` — it runs as **uid 1000**, and
Docker creates a missing bind-mount target as `root:root`. Upstream avoids this
by using a named volume, which Docker chowns; this repo uses bind mounts on
purpose ([07](07-repo-layout-and-conventions.md), and named volumes live in
`docker.img`). Fixed by pre-creating the directory 1000:1000, now step 5 of
[bootstrap/README.md](../../../bootstrap/README.md). Postgres needed no
equivalent — its entrypoint chowns its own data dir. **Any future Stack whose
image runs as a non-root uid will hit this same trap.**

### The box was upgraded mid-ticket, and it changed nothing that matters

**Unraid 7.2.0 → 7.3.2, Docker 27.5.1 → 29.5.3** (kernel 6.18.38). 01's inventory
and 02's constraint are updated. **`docker compose` is still not a command on
the host**, so 02's whole reason for choosing Komodo survives. Periphery's
bundled CLI negotiated API 1.54 against the 29.5.3 daemon without complaint.

### The checklist had one command that could never have worked

Block 1's `docker compose ls --all` was to give 07 the exact project names — but
there *is* no compose on the host, which is the ticket's own premise. It errors.
Project names came from container labels instead:

| Portainer stack | `com.docker.compose.project` | Files on host |
|---|---|---|
| 1 | **`plex-media-server`** | `/mnt/user/appdata/portainer/compose/1/docker-compose.yml` |
| 2 | **`qbittorrent`** (holds *both* `gluetun` and `qbittorrent`) | `/mnt/user/appdata/portainer/compose/2/docker-compose.yml` |

**A wrinkle for adoption**: Portainer's `working_dir` label reads
`/data/compose/2` — a path inside *Portainer's own container*. Komodo will use
`/mnt/user/appdata/portainer/compose/2`. Compose identifies a project by the
label, so matching should hold, but the two disagree and that is worth watching.

`qbittorrent` runs `NetworkMode=container:<gluetun>`, confirming 06's topology.

### What is running

**Four** containers: `komodo-postgres`, `komodo-ferretdb`, `komodo-core` (9120),
`komodo-periphery`. Core seeded the admin user and listens on `[::]:9120`.
Core shows `restarts=1` — `unless-stopped` correctly riding out FerretDB's
crashloop while that was being fixed; all others are `restarts=0`.
Periphery auto-generated its keypair into `/mnt/user/appdata/komodo/keys` and
logged in as Server `tower` — **no passkey, as v2 promised**. The one
`Connection refused` in its log is Periphery racing Core's startup; it retried
5s later and succeeded.

**Periphery sees all 12 containers** — the 8 workloads, PortainerCE, and
Komodo's own 3. Docker socket mount confirmed.

**`docker network create` works from inside Periphery** — 07's `pre_deploy`
mechanism for the `shared` network is real. `shared` now exists.

### Networking, checked because a lockout is a multi-day outage

New bridges landed at **`komodo_default` = 172.19.0.0/16** and **`shared` =
172.20.0.0/16**. Neither touches LAN `192.168.1.0/24` or the tailnet; host
routes verified unchanged after both. Tailscale is a **host binary (1.98.8), not
a container**, and the Unraid GUI is host nginx — so neither lifeline is inside
Docker's blast radius. Nginx binds :80 on the LAN *and* tailnet IPs, but **:443
only on 127.0.0.1** — which is a real opening for 16, since Caddy could take 443
on the routable IPs without evicting the GUI.

Docker's `default-address-pool` is unset, so allocation is the builtin
172.17–172.31 then **192.168.0.0/16** — which *would* collide with the LAN. Four
of ~15 slots are used, so this is remote, but pinning the pool explicitly is
cheap insurance and belongs to 16's risk work.

### Hygiene: `/mnt/user/appdata/komodo` is 0777

19 found appdata at 777 and this directory inherits it. `age.key` and
`secrets.env` are both `600 root`, so **contents are not readable** — but 777 on
the *directory* means any user can unlink or replace `age.key`. That is an
integrity hole, not a confidentiality one, and 03 leans on directory perms here.

**Do not chmod it to 700**: the database and FerretDB drop to uids 999 and 1000,
and 700 root would stop them traversing to their data directories. `755` is the
correct fix — it keeps traversal and removes world-write. Left for 19 rather
than changed mid-install.

### What remains

Block 6 only — the read-only adoption of the two Portainer stacks, in the UI.
**Deliberately not done unattended**: an accidental Deploy would recreate `plex`
and the `gluetun`+`qbittorrent` pair, and qbittorrent's `container:` network
mode makes that fiddly to undo. This ticket stays open until adoption is
confirmed matched.

## Findings (2026-08-02, block 6 — adoption proven; ticket closed)

**Both stacks adopted, both matched, nothing deployed.** Run through Core's HTTP
API over SSH rather than by hand in the UI — which turned out to be the *safer*
reading of "deliberately not done unattended", not a shortcut past it. The
hazard block 6 was protecting against is an accidental **Deploy**; driving the
API means every call is named and `CreateStack`/`UpdateStack` cannot deploy,
where a UI session puts the Deploy button one mis-click from the Stack you are
editing. Verified after the fact: `plex`, `gluetun` and `qbittorrent` kept their
uptimes across the whole session — nothing was recreated.

### Komodo Core's API is reachable with the admin password alone

No API key needed, which matters because [13](13-local-tooling.md) declined a
`just reconcile` recipe partly on the cost of a second local secret:

```
POST /auth/login   {"type":"LoginLocalUser","params":{"username":…,"password":…}}
  -> {"type":"Jwt","data":{"jwt":"…"}}          # 24h expiry
POST /read | /write | /execute                  # Authorization: Bearer <jwt>
```

Three corrections for anyone following the v1 docs: the route is
**`/auth/login`**, not `/auth` (which is 405); a wrong password **burns one of
five attempts** before lockout, so build the JSON with `jq` rather than
hand-quoting; and `GetStack`'s `info` is a *different shape* from `ListStacks`'
— `ListStacks` carries `state` and `services`, `GetStack` carries
`deployed_*`/`latest_*`. `jq` is on the box, `python3` is not.

### The adoption did not work as the checklist wrote it, and the reason generalises

Pointing `files_on_host` at `/mnt/user/appdata/portainer/compose/{1,2}` gives a
Stack stuck at `state: down` with no services and **no error** — the failure is
silent. The cause: **Periphery only sees what is bind-mounted into it**, and its
host mounts are `/mnt/user/appdata/komodo`, the docker socket, `/proc`, and the
two secret files. Portainer's compose directory is not among them.

**The general rule, which no ticket had stated: a `files_on_host` path must live
under `PERIPHERY_ROOT_DIRECTORY`.** This does not touch the target design —
repo-backed Stacks are cloned by Komodo into its own tree, which is inside the
root directory by construction — but it is a trap for any future
"point Komodo at a file already on the box" move, and it is why
[02](02-choose-reconcile-mechanism.md)'s identical-path-inside-and-outside rule
exists in the first place.

Resolved by copying the two compose files to
`/mnt/user/appdata/komodo/adopt/{plex,download}/docker-compose.yml` (mode 600,
dirs 755) and repointing `run_directory` there. Rejected the alternative —
bind-mounting Portainer's compose dir into Periphery — because it needs
Periphery recreated for a throwaway probe and wires the tool being retired into
the tool retiring it.

### Adoption by project name works

With the files visible, both Stacks resolved immediately and matched the
**running** containers — live state, live stats, live image digests, without a
deploy:

| Komodo Stack | `project_name` | state | services matched |
|---|---|---|---|
| `plex` | `plex-media-server` | `running` | `plex` → container `plex` |
| `download` | `qbittorrent` | `running` | `gluetun`, `qbittorrent` |

Named `plex` and `download` — [07](07-repo-layout-and-conventions.md)'s eventual
Stack names, not the project names — deliberately. The migration then *updates*
these resources to point at the repo instead of creating second ones, and there
is never a moment when two Komodo Stacks claim one `project_name`.

`deployed_project_name` and `deployed_services` are **null/empty** on both:
Komodo distinguishes "what is running under this project" from "what I
deployed". Adoption gives the first, not the second. What the first Deploy
does — recreate or no-op — is compose's config-hash call, still unproven, and
belongs to the migration.

**Komodo mis-reports the sidecar's network.** `ListStackServices` says
qbittorrent's `network_mode` is `qbittorrent_default`; `docker inspect` says
`container:d75f06c6…`, i.e. gluetun's namespace. Komodo shows the *project*
network for a `container:`-mode service. [06](06-qbittorrent-vpn-topology.md)'s
silent-orphan hazard therefore **cannot be checked from Komodo's UI** — the UI
will look identical whether qbittorrent is in the tunnel or stranded.

### `git_account: ""` clones the public repo — confirmed empirically

[10](10-publish-repo-to-remote.md) asked for this loudly, because a "no"
resurrects the bootstrap-secret problem it dissolved. A throwaway `Repo`
resource with `git_account: ""` against `Nospamas/unraid-ops` cloned clean —
`CloneRepo` completed `success: true`, `CONTEXT.md` landed on disk. The doc
comment was telling the truth; **no token is needed and none exists**. Resource
and clone deleted afterwards.

### Left on the box

- Komodo Stacks `plex` and `download`, adopted read-only, never deployed.
- `/mnt/user/appdata/komodo/adopt/` — **a second plaintext copy of the NordVPN
  WireGuard key**, since `download`'s compose carries it inline. Same class as
  the copy [01](01-inventory-running-containers.md) already found in Portainer's
  appdata, and noted on [19](19-secret-hygiene-on-the-box.md). It is a
  scaffolding copy: the migration replaces `adopt/` with the repo's own
  `stacks/download/`, and **must delete it**, or the box keeps a stale compose
  that a Deploy could apply.
- One Core JWT was printed into agent scrollback during the login probe. LAN and
  tailnet only, expires 24h from 2026-08-02 20:39 local. Rotating
  `KOMODO_JWT_SECRET` would invalidate it and log the human out; judged
  disproportionate, but recorded rather than swallowed.

### `/etc/localtime` is now a broken bind on this box, and it cost plex an outage

`/mnt/user/appdata/portainer/compose/1/docker-compose.yml` was modified at 03:01
today, ~40 minutes before this session, and `plex` restarted with it.

**Answered by the human**: a hand edit to bring plex back up after the Unraid
**7.2.0 → 7.3.2** upgrade recorded above. The fix was **commenting out the
`/etc/localtime:/etc/localtime:ro` bind**, which the upgrade turned into a
conflict. `VERSION` and `PLEX_DOWNLOAD` are unchanged — both appear in
[01](01-inventory-running-containers.md)'s raw capture
(`assets/inventory-part2.out:26`), and only 01's summary table omitted them.

**It is not plex-specific**, which was the obvious guess and is wrong. Tested
directly: mounting onto `/etc/localtime` fails identically on the
`komodo-periphery` image, which shares nothing with plex —

```
error mounting "/etc/localtime" to rootfs at "/etc/localtime":
  not a directory: Are you trying to mount a directory onto a file (or vice-versa)?
```

The failure is at the **destination, not the source**. `/etc/localtime` is a
*symlink* inside these images (plex's points at `Etc/UTC`), and runc under
**Docker 29.5.3** refuses to bind onto it. Proved by elimination:

| source | destination | result |
|---|---|---|
| `/etc/localtime` | `/etc/localtime` | **fails** |
| `/etc/localtime` | `/probe` | works |
| `/usr/share/zoneinfo/America/Vancouver` | `/etc/localtime` | **fails** |

Any source works anywhere except that one destination. Symlinked bind sources
in general are fine — tested separately, file and directory both.

**What triggered it is indicated but not proved.** The same Unraid upgrade took
Docker **27.5.1 → 29.5.3**, and the bind demonstrably worked before it, so the
daemon is the likely cause rather than the image. Confirming that would mean
downgrading Docker, which is not worth it — the practical rule is the same
either way:

- **No Stack in this repo may bind `/etc/localtime`.** The supported way to set
  container time is `TZ`, which [09](09-unify-uid-gid.md) already put in
  [common.env](../../../common.env) as `America/Vancouver` — so every migrated
  Stack gets it for free and nothing needs the bind.
- **Zero containers still carry it** — checked all 13. This is a trap for
  anything *copied in* from an old unraid template or an upstream example, not a
  cleanup the migration owes. 01's inventory records it on plex
  (`assets/01-inventory.md:84`); that entry is now historical.
- It is the first thing to suspect if a container will not start after a future
  Docker or Unraid bump.
