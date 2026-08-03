# 23 — Migrate plex

Type: task
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03
Blocked by: 20

## Question

Adopt plex into git — the awkward one.

- **Blocked by [20](20-chown-to-99-100.md).** Plex runs as 1000:1000 today and
  drops to 99:100; until the chown has run it cannot read its own 20G appdata.
- **`/dev/dri` passthrough**, and group access to it depends on the container
  user's groups. [09](09-unify-uid-gid.md) flagged this as a check, not an
  assumption: after the first deploy, play something that transcodes and confirm
  the dashboard still says `(hw)`. If it does not, that is a group problem — it
  is **not** a reason to give plex its old uid back.
- **Appdata is `${APPDATA}/plexmediaserver`**, not the Stack name.
- **Pin `VERSION` and the image digest.** Both `VERSION` and `PLEX_DOWNLOAD`
  exist on the running container
  ([assets/inventory-part2.out:26](../assets/inventory-part2.out)).
- **`PLEX_CLAIM` is not needed** — one-shot, already claimed
  ([03](03-secrets-handling.md)).
- **Never bind `/etc/localtime`.** The existing compose in Portainer's appdata
  has it commented out for exactly this reason
  ([11](11-stand-up-komodo.md)); do not copy it back in.

Plex already runs from a Portainer compose file, so this Stack is a lift rather
than a translation — but the Komodo Stack named `plex` **already exists**,
adopted read-only against project `plex-media-server`. This ticket **updates**
that resource to point at the repo; it must not create a second one.

Deleting `/mnt/user/appdata/komodo/adopt/plex/` is part of finishing.

## Settled early by [19](19-secret-hygiene-on-the-box.md) / [20](20-chown-to-99-100.md)

- **The chown is done and plex already runs 99:100 with `UMASK=002`**, its
  Portainer stack edited and redeployed. This ticket is no longer blocked and no
  longer has to perform the uid move — it is a lift into git.
- **The `/dev/dri` check is answered: it was never a risk.** `renderD128` is
  `crwxrwxrwx`, so the container user's groups are irrelevant. Plex's log under
  the new uid says `adding /dev/dri/renderD128 to group group1sck` and
  `permissions for /dev/dri/card0 are good`. Confirming a transcode still says
  `(hw)` is worth doing once, but it is a spot-check, not a gate.
- **There is no compose binary on the box** — drive the daemon remotely with
  `DOCKER_HOST=ssh://root@tower` if a stack must be run outside Komodo.
- The current compose is backed up at
  `/mnt/user/appdata/portainer/compose/1/docker-compose.yml.bak-19`.

## Resolution (2026-08-03)

**Plex is a Stack, on `shared`, with all five libraries intact** — 1853 movies,
217 shows, 81 + 980 + 2 in the three audio sections, counted through the API
after the deploy. `https://plex.rbrb.in` answers 200 from the tailnet and 403
from a container on `shared`, and `32400` stays published because every client
that is not a browser reaches plex there.

### Adoption in place recreates, and the map's open question is answered

This is the first Stack to take over a **Portainer** compose project rather than
replace an unraid container, and the answer is **recreate, not no-op**: the
config hash differs, so compose destroyed `plex` and built
`plex-media-server-plex-1` in the same project against the same appdata.
Two facts fall out, both of which [24](24-migrate-download-stack.md) needs:

- **The container is renamed** to `<project>-<service>-1`, so anything
  addressing it *by container name* breaks — homepage's `container:` entry did,
  and was updated in the same push.
- **The network alias survives.** The container answers to `plex` on `shared`
  regardless of the project name, so service-name URLs do not break.

`project_name` stays `plex-media-server`, which is Portainer's, not the Stack's
name. Renaming it would have built a second container beside the running one.

### `VERSION` was the real find, and it unpinned the digest

The running container carried `VERSION=1.43.1.10495-10cfae054` and
`PLEX_DOWNLOAD=.../plex-media-server-builds`, and its log showed why that
matters: **at every start it downloaded an 84MB .deb and installed it over the
image**. The digest in the compose file described a container that no longer
existed by the time it served a byte, and Renovate could not see the version at
all.

That build is not on the public path — `plex-media-server-new` 403s it — so it
was a Plex Pass build, pinned for **B580 support**, which is now mainline. So
the pin is spent: `VERSION: docker` hands versioning back to the image, and the
image is pinned at `1.43.3.10828-00f62d37d-ls317`, which is the current public
release and **ahead** of the build it replaces. The log now says
`Docker is used for versioning skip update check`.

The rule went to [docs/conventions.md](../../../docs/conventions.md), *Images*:
an image that updates itself at runtime is not pinned.

### `/mnt/transcode` was mounted at a path plex never asked for

`TranscoderTempDirectory="/transcode"`, and the bind was `/mnt/transcode` — a
directory that has been **empty since 2025**. Plex has been transcoding into
`/config` all along. Fixed by binding `${APPDATA}/transcode` → `/transcode`
rather than deleting the bind, since plex's own setting is the one that says
where it wants to go; the container now logs `Setting permissions on /transcode`.

### `PLEX_CLAIM` is gone, and so is the hardware-transcode gate

Dropped, as [03](03-secrets-handling.md) said — the server is claimed, and the
token had long expired. `/dev/dri` passed on its own: `renderD128` joins
`group4r3d` and `permissions for /dev/dri/card0 are good`, exactly as under the
old uid. Playing something that transcodes remains a spot-check, not a gate.

### Rollback, and what it costs

The 19G appdata was never touched, and Portainer still holds the original
compose at `/mnt/user/appdata/portainer/compose/1/docker-compose.yml` — until
[25](25-retire-portainer.md), redeploying that stack restores the old container.
The one forward-only step is the **1.43.1 → 1.43.3 database migration**, so the
live databases were copied, container stopped, to
`/mnt/user/appdata/backup-23-plex-db/` (628M) before the deploy. Plex's own
dated backups sit beside the originals as a second copy. **Delete the backup
directory once a week has passed without a rollback.**

### Plex is on the internet, and the repo cannot see it

Verified from outside both networks: `http://75.155.182.130:32400/identity`
answers with **this server's** machineIdentifier. `ManualPortMappingMode="1"` and
`PublishServerOnPlexOnlineKey="1"` in Preferences.xml, plus a port forward on
rb's router that predates this repo.

This does not make the deploy wrong — plex guards itself with its own account
auth, and it was open before this ticket as much as after. It makes two of the
map's claims wrong, because `grep -rn x-published stacks/` says nothing faces
the internet and `scripts/check-exposure.sh` only ever reasoned about the
**Caddy** path. Spawned [31](31-plex-own-internet-exposure.md); left as found
until 31 rules on it.
