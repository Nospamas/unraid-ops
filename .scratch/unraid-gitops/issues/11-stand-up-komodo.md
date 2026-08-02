# 11 — Stand Komodo up on the box

Type: task (HITL)
Status: open
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
