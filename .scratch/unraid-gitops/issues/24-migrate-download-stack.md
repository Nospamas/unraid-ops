# 24 — Migrate the download Stack (gluetun + qbittorrent)

Type: task
Status: open
Assignee: Nospamas
Blocked by: 20

## Question

The riskiest migration, and the one every earlier ticket has been loading
warnings onto.

- **Blocked by [20](20-chown-to-99-100.md)** — gluetun runs 1000:1000 and
  qbittorrent 1001:1001 today.
- **One Stack, two Services**, because `network_mode: service:gluetun` cannot
  cross compose projects ([07](07-repo-layout-and-conventions.md)).
- **Recreating gluetun alone leaves qbittorrent in a dead namespace, silently**
  ([06](06-qbittorrent-vpn-topology.md)) — and Komodo **mis-reports** a
  `container:`-mode service's network, so the UI looks identical either way
  ([11](11-stand-up-komodo.md)). Verification has to be `docker inspect`, not
  the dashboard.
- **Drop the two misspelled firewall env vars, do not correct them.** Spelling
  `FIREWALL_OUTBOUND_SUBNETS=0.0.0.0/0` properly would route everything around
  the tunnel; the typo is the only reason the kill switch holds.
- **The *arr download-client repoint is a hand edit in four UIs** — that setting
  lives in each service's appdata and no push can perform it.
  `http://gluetun:30024`, the namespace owner, not `qbittorrent`.
- **qbittorrent's `AuthSubnetWhitelist` must gain `172.20.0.0/16`.**
  [08](08-deploy-homepage.md) found the widget works unauthenticated today only
  because traffic via the published port arrives with a LAN source address. Once
  homepage and the *arr address `gluetun:30024` over `shared`, the source
  becomes the bridge subnet and every unauthenticated caller starts failing —
  for no visible reason.
- The Komodo Stack `download` **already exists**, adopted read-only against
  project `qbittorrent`. Update it; do not create a second.
- Delete `/mnt/user/appdata/komodo/adopt/download/` when done — it holds **a
  second plaintext copy of the NordVPN key** and a compose file a Deploy could
  still apply ([19](19-secret-hygiene-on-the-box.md)).

State the rollback before deploying. Leech-only is a settled posture, not a
defect — do not buy port forwarding to "fix" it.

## Settled early by [19](19-secret-hygiene-on-the-box.md) / [20](20-chown-to-99-100.md)

- **The chown is done**; gluetun and qbittorrent both run 99:100, qbittorrent
  with `UMASK=002`. Recreated together and verified: qbittorrent's
  `HostConfig.NetworkMode` is `container:<live gluetun id>`, gluetun healthy, and
  the exit IP (`94.140.8.185`) differs from the host's (`75.155.182.130`) — the
  tunnel holds. Not blocked any more.
- **The firewall typo is subtler than this ticket records, and the warning
  stands.** Gluetun's env holds *both* spellings: `FIREWALL_OUTBOUND_SUBNET=
  0.0.0.0/0` (misspelled, inert) **and gluetun's own `FIREWALL_OUTBOUND_SUBNETS=`
  — correct spelling, empty**, which is what is actually in force. Correcting the
  typo would set `0.0.0.0/0` and route everything around the tunnel.
  `FIREWALL_VPN_INPUT_ALLOW=192.168.1.0` is likewise malformed and inert. **Carry
  both across verbatim.**
- Compose backed up at
  `/mnt/user/appdata/portainer/compose/2/docker-compose.yml.bak-19`.

## Settled early by [23](23-migrate-plex.md)

23 was the first Stack to take over a Portainer project, so the questions this
ticket inherited are now answered rather than assumed:

- **Adoption in place recreates.** Compose destroys the container and rebuilds
  it in the same project against the same appdata — it does not no-op. For this
  Stack that is the *safe* direction, since gluetun and qbittorrent are one
  compose project and are recreated together, which is exactly what
  [06](06-qbittorrent-vpn-topology.md)'s hazard requires.
- **The project to inherit is `qbittorrent`, not `download`** — both containers
  carry `com.docker.compose.project=qbittorrent`, with services `gluetun` and
  `qbittorrent`. So `project_name = "qbittorrent"` while the Stack is `download`.
- **Both containers get renamed** to `qbittorrent-gluetun-1` and
  `qbittorrent-qbittorrent-1`, which breaks anything addressing them by
  container name — homepage's two `container:` entries do, and must move in the
  same push.
- **The `gluetun` network alias survives** the rename, so the *arr's
  `http://gluetun:30024` keeps resolving once they are all on `shared`.
