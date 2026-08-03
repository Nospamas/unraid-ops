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
