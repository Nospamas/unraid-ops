# 23 — Migrate plex

Type: task
Status: open
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
