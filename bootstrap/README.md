# Bootstrap

Komodo runs everything else on this box. Nothing runs Komodo, so these three
containers are stood up by hand — once now, and again only if the box is
rebuilt. This directory is in git for the second case.

Decided by [ticket 02](../.scratch/unraid-gitops/issues/02-choose-reconcile-mechanism.md),
installed by [ticket 11](../.scratch/unraid-gitops/issues/11-stand-up-komodo.md).

## The thing that makes this awkward

There is no `docker compose` on the Unraid host — no plugin, and the OS rebuilds
from `/boot` on every reboot
([ticket 01](../.scratch/unraid-gitops/issues/01-inventory-running-containers.md)).
That is the whole reason Komodo was chosen: its Periphery image carries compose
and git so the host does not have to.

Which leaves the bootstrap needing a compose it does not have yet. The way out
is that **the Periphery image is itself a compose implementation**, so it can
deploy the stack it belongs to:

```sh
alias dc='docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/user/appdata/komodo:/mnt/user/appdata/komodo \
  -w /mnt/user/appdata/komodo/bootstrap \
  --entrypoint docker ghcr.io/moghtech/komodo-periphery:2.3.1 compose -p komodo'
```

Portainer is the fallback — it embeds compose too, and it is still on the box
until [ticket 02](../.scratch/unraid-gitops/issues/02-choose-reconcile-mechanism.md)
retires it. Paste `compose.yaml` into a web-editor stack and supply the env vars
in its UI. Prefer the alias above: it keeps Komodo's secrets out of Portainer's
database, and it still works after Portainer is gone.

## Order

Everything lives under `/mnt/user/appdata/komodo`, which is also
`PERIPHERY_ROOT_DIRECTORY` — **identical inside and outside the container**, or
compose path resolution breaks
([komodo#180](https://github.com/moghtech/komodo/discussions/180)).

1. **Place the age key** at `/mnt/user/appdata/komodo/age.key`, mode 600, from
   KeePassXC. Not on `/boot` — Unraid Connect ships the flash drive off-site
   ([ticket 03](../.scratch/unraid-gitops/issues/03-secrets-handling.md)).
2. **Place the sops binary** at `/mnt/user/appdata/komodo/bin/sops`, mode 755 —
   one static Go binary, matching the version pinned in
   [.mise.toml](../.mise.toml):

   ```sh
   curl -fsSL -o /mnt/user/appdata/komodo/bin/sops \
     https://github.com/getsops/sops/releases/download/v3.13.3/sops-v3.13.3.linux.amd64
   echo "e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b  /mnt/user/appdata/komodo/bin/sops" \
     | sha256sum -c -
   chmod 755 /mnt/user/appdata/komodo/bin/sops
   ```
3. **Put this directory** at `/mnt/user/appdata/komodo/bootstrap`.
4. **Decrypt the secrets** — the one `sops` invocation that is not a
   `pre_deploy`, because there is no Komodo yet to run one:

   ```sh
   SOPS_AGE_KEY_FILE=/mnt/user/appdata/komodo/age.key \
     /mnt/user/appdata/komodo/bin/sops --decrypt secrets.sops.env > secrets.env
   chmod 600 secrets.env
   ```

5. **Pre-create FerretDB's state directory, owned by 1000:1000.** Docker creates
   a missing bind-mount target as `root:root`, and FerretDB runs as uid 1000 —
   so without this it crashloops on `open /state/state.json: permission denied`.
   A named volume would be chowned automatically; a bind mount is not, and the
   bind mount is deliberate (see the volume comment in `compose.yaml`).

   ```sh
   mkdir -p /mnt/cache/appdata/komodo/ferretdb/state
   chown -R 1000:1000 /mnt/cache/appdata/komodo/ferretdb
   ```

   Postgres needs no equivalent — its entrypoint chowns its own data directory.
   Note 1000:1000 is **not** the repo's usual 99:100
   ([ticket 09](../.scratch/unraid-gitops/issues/09-unify-uid-gid.md)); that rule
   governs Stacks, and the bootstrap is not one. FerretDB's uid is baked into
   the image.

6. **Up**, with both env files:

   ```sh
   dc --env-file compose.env --env-file secrets.env up -d
   ```

7. **Log in** at `http://192.168.1.195:9120` with the admin credentials from
   `secrets.env` — user `admin`, password generated per-install, never a default.

   `KOMODO_INIT_ADMIN_*` is **create-if-absent**, verified by restarting Core
   with the admin already present: it seeds nothing and logs nothing. So
   **prefer not to change the password in the UI.** A UI change survives every
   restart and the committed value never catches up, which forks the truth two
   ways: `secrets.sops.env` stops being what logs you in, and a rebuild reseeds
   the *old* password while your password manager holds the new one — quietly
   breaking the clone-plus-one-key story below. If you do change it, change
   `secrets.sops.env` to match in the same sitting (`just secret bootstrap`).

   Komodo enforces no strength of its own: Core's startup config reads
   `min_password_length: 1`. It rate-limits at 5 attempts per 15s, and issues
   session JWTs with a 1-day TTL.

8. **Declare this repo to Komodo**, from a laptop clone with `age.key` in place:

   ```sh
   just bootstrap
   ```

   Everything else Komodo runs comes from git, but the ResourceSync that reads
   git cannot itself come from git — so this one resource is created here, from
   [komodo/sync.toml](../komodo/sync.toml), and then declares itself. Without
   this step a rebuilt box is a running Komodo that has never heard of this
   repo. The recipe is idempotent, and `just reconcile` afterwards deploys
   without waiting for the 15-minute poll.

## What is a secret here, and why it cannot follow the usual route

Every other Stack decrypts its secrets in a Komodo `pre_deploy`. This one
cannot, so `secrets.env` is written by hand and stays on disk beside the compose
file. The values in it are **not** in the low-value class the map's secret note
describes: `KOMODO_JWT_SECRET` signs Komodo's own sessions, and Core answers on
the LAN, so leaking it means full control of every container on the box.

Regenerating them all is a `just secret bootstrap` edit plus a redeploy; only
`KOMODO_DATABASE_*` needs care, since Postgres already has the role — and the
same pair is embedded in `FERRETDB_POSTGRESQL_URL`, so both move together.

## Rebuilding the box

Clone the repo, restore `age.key` from KeePassXC, re-fetch the sops binary, then
steps 3–8. Appdata under `/mnt/user/appdata/komodo` carries the Core/Periphery
keypair, and `/mnt/cache/appdata/komodo/postgres` carries the database — the
same files, reached without shfs. A restore of appdata plus this file is the
whole of it. Everything Komodo manages comes back from the repo through
ResourceSync — which step 8 is what puts back.

## The database

**FerretDB in front of Postgres**, not MongoDB. Komodo supports only these two,
and Postgres is the one the human already knows how to back up — `pg_dump`
against `komodo-postgres` rather than `mongodump`. Neither the database nor the
adapter publishes a port; Core reaches FerretDB at `ferretdb:27017` on the
compose network.

Pin both images together: the `postgres-documentdb` tag names the FerretDB
release it was built against (`17-0.107.0-ferretdb-2.7.0` ↔ `ferretdb:2.7.0`),
so they must be bumped as a pair. Upstream warns that updates can be breaking.

## Updating these four images

**There is no `komodo.toml` here, and there never will be.** Komodo Core can
redeploy itself (Periphery does the work; the update log looks failed because
Core restarts mid-deploy, but it succeeds). Periphery cannot — redeploying it
kills the process running the deploy — and upstream requires Periphery match
Core's version before builds and clones work again. So the automatable half is
chained to the manual half, and self-management would only buy a window where
Core is ahead of Periphery.

This is therefore the one thing on the box that is **not** GitOps'd:

1. Renovate opens a bump PR — `komodo` (Core + Periphery) or `ferretdb`
   (FerretDB + postgres-documentdb), always grouped as pairs, never automerged.
2. Merge it.
3. `ssh root@tower`, `cd $PERIPHERY_ROOT_DIRECTORY/bootstrap && git pull`,
   `docker compose up -d`.
4. Confirm Core and Periphery are both healthy and the Server shows connected.

Between 2 and 3, `main` claims a version the box is not running. The PR body
carries these steps as a reminder — see the `prBodyNotes` in
[.renovaterc.json5](../.renovaterc.json5). Back up Postgres before a FerretDB
pair bump.
