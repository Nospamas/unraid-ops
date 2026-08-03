# 24 — Migrate the download Stack (gluetun + qbittorrent)

Type: task
Status: open
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
