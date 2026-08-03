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
