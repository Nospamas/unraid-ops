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
- **Point Core at the remote** from [10](10-publish-repo-to-remote.md) with the
  git account and HTTPS token.
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
