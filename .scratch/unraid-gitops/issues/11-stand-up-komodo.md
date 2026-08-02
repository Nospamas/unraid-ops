# 11 — Stand Komodo up on the box

Type: task (HITL)
Status: open
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
  supported as of v1.18.0), and `komodo-periphery`. Periphery has a Community
  Apps entry, so it installs the ordinary unraid way; Core and the database
  need standing up too, and until Komodo exists there is nothing to deploy them
  *with* — so this bootstrap step is by hand, and it is the last thing on the
  box that will be.
- **Get `PERIPHERY_ROOT_DIRECTORY` right.** Per 02 it must be an *identical*
  path inside and outside the container or stack path resolution breaks — mount
  `/mnt/user/appdata/komodo:/mnt/user/appdata/komodo`, not the usual
  `:/etc/komodo`. This is the single most likely thing to go wrong.
- **Point Core at the remote** from [10](10-publish-repo-to-remote.md) —
  `https://github.com/Nospamas/unraid-ops`, **public, no credential**. See the
  section 10 added below before configuring a git account.
- **Confirm Periphery sees the host's containers** — all eight workloads plus
  Portainer should appear. This is the check that the docker socket mount and
  the passkey handshake are right.
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
