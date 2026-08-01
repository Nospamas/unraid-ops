# 03 — Decide how secrets live in the repo

Type: grilling
Status: open
Blocked by: 02

## Question

The repo needs API keys for the *arr services and qbittorrent (homepage widgets
consume them), plus VPN credentials for the torrent container. Where do they
live, and how do they reach a running container?

**The full set, per [01](01-inventory-running-containers.md)**: the NordVPN
`WIREGUARD_PRIVATE_KEY`, `PLEX_CLAIM`, calibre's `PASSWORD` + `CUSTOM_USER`, and
the sonarr/radarr/prowlarr/qbittorrent API keys. Note the last group are **not**
environment variables — they live in each service's `/config/config.xml` inside
appdata, so nothing needs to inject them *into* the *arr containers. Homepage is
their only consumer.

**Do not raise rotation as a blocker.** The human has ruled the leaked WireGuard
key and calibre password low-severity; see the map's Secret severity note.
Picking a mechanism here will re-issue the WireGuard key as a side effect, which
settles it without a separate act.

Options in play:

- **SOPS + age**, matching the home-ops habit — encrypted values committed here,
  the age key held on the unraid box. Cost: the reconcile mechanism must
  decrypt before applying, which ticket 02 will have established is possible or
  not.
- **Off-git `.env` on the box** — compose files reference `${SONARR_KEY}`, the
  real values never leave the host. Simplest, but the box holds state the repo
  cannot rebuild.
- **An external secrets manager** — Infisical, 1Password Connect. Most
  machinery, best rebuild story.

Resolve alongside it: where the age key (or equivalent root secret) is kept so a
box rebuild is possible, and whether a secret ever appears in plaintext on disk
between decryption and container start.

The answer states the mechanism and the rebuild story in a few lines.
