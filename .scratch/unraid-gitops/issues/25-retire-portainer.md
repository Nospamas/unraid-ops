# 25 — Retire Portainer

Type: task
Status: closed
Assignee: Nospamas
Resolved: 2026-08-05
Blocked by: 23, 24

## Question

[02](02-choose-reconcile-mechanism.md) settled that Portainer is **removed**
once its two stacks are adopted by compose project name. This is that removal.

Two conditions the map attached, both now met or met by the blockers:

- **Its two stacks are git-owned** — [23](23-migrate-plex.md) and
  [24](24-migrate-download-stack.md).
- **Portainer is a second lifeline** to browser-reachable container control
  until SSH proves itself. [11](11-stand-up-komodo.md) and
  [08](08-deploy-homepage.md) both ran end to end over SSH, including a full
  Komodo install and two deploys, so that condition is spent — but say so
  explicitly rather than letting it lapse quietly, because after this the ways
  into the box are SSH and the Unraid GUI on port 80.

Removing it also removes the plaintext NordVPN key in
`/mnt/user/appdata/portainer/compose/2/`
([19](19-secret-hygiene-on-the-box.md)) and frees ports 8000 and 9000.

Decide what happens to `/mnt/user/appdata/portainer` — deleted, or kept as a
cold archive until the migrations have proven themselves.

## Added by [19](19-secret-hygiene-on-the-box.md)

**The database holds the WireGuard key too.** `portainer.db` *and*
`backups/portainer.db.bak` both match, not just `compose/2/docker-compose.yml`.
So "kept as a cold archive" **preserves the plaintext key** — that is now a real
input to this ticket's disposition question, not a tidiness one. Also note
`.bak-19` copies of both compose files now sit alongside them.

Portainer's own copies are the **best-protected** on the box (600 in a 700 dir),
so this is about deliberate disposal, not an active leak.

## Added by [24](24-migrate-download-stack.md)

**Both blockers are closed, and the plaintext key has a fourth home.** The
download Stack is git-owned, so Portainer holds no stack anyone deploys — but
`grep -rl` now also finds the WireGuard key in
`/mnt/user/appdata/komodo/postgres/data/`, left by the Stack
[11](11-stand-up-komodo.md) adopted with the compose file inline. Removing
Portainer therefore removes three of four copies, not all of them, and this
ticket should say so rather than claim the leak is closed.

Portainer's compose is also the **rollback** for 24 until roughly 2026-08-10.
Retiring it before then trades a live rollback for tidiness.

## Carried into [map 02](../map.md)

Map 01 is archived with this ticket still open, and it comes forward unchanged
because it now **blocks** [38](38-homepage-tile-gaps.md): the Portainer tile is
the last reader of `HOMEPAGE_VAR_HOST`, the box's raw LAN IP that
[26](26-host-state-scope.md) ruled git cannot own. The dashboard cannot be
finished until Portainer's fate is settled.

**The lifeline condition is spent, on the record.** Komodo has run several
deploys end to end and is a second browser door to container control at `:9120`,
which keeps its host port precisely so the tooling that repairs Caddy is not
behind Caddy. Line 21 above says "the Unraid GUI on port 80" — stale;
[15](15-move-unraid-gui-ports.md) moved it to **8008**.

**Mind the date.** The rollback window above runs to roughly **2026-08-10**.
Taking this ticket before then knowingly gives up [24](24-migrate-download-stack.md)'s
rollback for the gluetun/qbittorrent pair. Either wait it out or say on
resolution that the trade was made deliberately.

## Answer

**Portainer is gone — container, image, Unraid template, autostart entry and
appdata — and no trade was made, because the rollback it was being held for did
not exist.**

### The rollback was already dead, and the date was moot

`compose/2/docker-compose.yml` asks for `image: qmcgaw/gluetun:latest`, and
[24](24-migrate-download-stack.md) established that the build actually running
was a **master build with no tag that reproduces it** — `fdf049f8`, 2025-11-16.
The box now holds exactly one gluetun image, `sha256:fa19cc76…`, which is the
`v3.41.3` currently pinned; the November build has aged out of the cache.
Redeploying that compose today would have pulled a *third* build — neither the
old one nor the pinned one. It was a **record of the prior configuration, not a
runnable rollback**, so waiting until 2026-08-10 bought nothing and nothing was
given up.

What *is* a live rollback for 24 is
`/mnt/user/appdata/backup-24-{gluetun,qbittorrent}` (21M), which never depended
on Portainer and **is untouched** — still there, still deletable on schedule.

The record itself also survives without the file: this repo documents every
divergence from the original in
[stacks/download/compose.yaml](../../../stacks/download/compose.yaml)'s comments
and in 24's answer — the image choice, the four cargo variables dropped, `TZ`,
`PUID`/`PGID`, and the ports.

### The leak is closed, further than expected

The disposition question was **delete**, not cold-archive, precisely because
three of the four copies *were* the archive. Removing appdata took all four —
`compose/2/docker-compose.yml`, its `.bak-19`, `portainer.db` and
`backups/portainer.db.bak` — plus a plaintext `PLEX_CLAIM` token in `compose/1`
that nothing had counted.

This ticket predicted "three of four copies, not all of them". That is now
wrong, in the good direction: the fourth, in
`/mnt/user/appdata/komodo/postgres/data/`, **has since vacuumed away**. A grep
for the key value over all of `/mnt/user/appdata` and `/boot/config` now returns
**one file**:

```
/mnt/user/appdata/komodo/stacks/download/stacks/download/secrets.env
```

which is `0600 root`, written by `pre_deploy` from the sops secret, and is the
one plaintext copy the running Stack requires. **The WireGuard key is no longer
loose on this box.**

### The lifeline condition, spent on the record

Everything in this session ran over SSH, including the removal itself. The doors
into the box are now **SSH over tailscale**, **Komodo at `:9120`** — which keeps
its host port so the tooling that repairs Caddy is not behind Caddy — and the
**Unraid GUI at `:8008`** ([15](15-move-unraid-gui-ports.md)). Portainer's `:9000`
was the fourth and is not replaced.

### What was run

```
docker stop PortainerCE && docker rm PortainerCE
rm /boot/config/plugins/dockerMan/templates-user/my-PortainerCE.xml
# drop the PortainerCE line from /var/lib/docker/unraid-autostart
rm -rf /mnt/user/appdata/portainer
docker rmi portainer/portainer-ce:latest
```

The last three lines are the ones a `docker rm` alone would have missed: the
template would have kept offering Portainer from the Docker tab, and the
autostart entry would have outlived the container it named.

Verified after: no container, `/mnt/user/appdata/portainer` gone, **host ports
8000 and 9000 both free**.

### The homepage tile went with it

[38](38-homepage-tile-gaps.md) counted the Portainer tile among its gaps, but 38
sits behind [35](35-add-tautulli.md) and [36](36-add-bazarr.md), so waiting meant
a dead tile on the dashboard rb is meant to open first. Removing a tile for a
service that no longer exists is cleanup, not a layout decision, so it was done
here: the tile, the `HOMEPAGE_VAR_HOST` variable it was the last reader of, and
the comment promising it. Homepage was redeployed and verified healthy with the
variable absent — **38 is no longer blocked by this ticket**, and only its four
additions remain.

Two stale references went too:
[bootstrap/README.md](../../../bootstrap/README.md) offered Portainer as the
compose fallback and now says there is none, and
[stacks/download/compose.yaml](../../../stacks/download/compose.yaml) explained
its `3002x` loopback ports as dodging a port Portainer no longer holds. The
ports stay — a contiguous block reads better than the one it was avoiding.

### Surfaced: five orphan Unraid templates

`/boot/config/plugins/dockerMan/templates-user/` still holds `my-sonarr.xml`,
`my-radarr.xml`, `my-prowlarr.xml`, `my-calibre.xml` and `my-lazylibrarian.xml`
(plus `.bak-19` copies, which differ only in `UMASK` `022`→`002` and hold no
secrets). Each names its container by the **bare** service name, while the
Stacks run `<service>-<service>-1` — so recreating one from Unraid's Docker tab
would start a **second** container on the same appdata, competing with the
Komodo Stack. Ticketed as
[41](41-orphan-unraid-templates.md); out of scope here.
