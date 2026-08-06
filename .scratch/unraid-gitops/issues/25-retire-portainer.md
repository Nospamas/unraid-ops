# 25 — Retire Portainer

Type: task
Status: open
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
