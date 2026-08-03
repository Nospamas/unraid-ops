# 24 — Migrate the download Stack (gluetun + qbittorrent)

Type: task
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03
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

## Resolution

**`download` is a Stack, gluetun and qbittorrent are on `shared`, and the
tunnel held across the recreate.** 23 torrents, all seeding, `/downloads`
unchanged. The pair is the last of the eight adopted workloads — git now owns
every container on the box except Portainer and Komodo's own four.

Verified rather than reported, because a green reconcile is not a running
service:

- `qbittorrent-qbittorrent-1`'s `HostConfig.NetworkMode` is
  `container:72a4bc92…`, the **live** gluetun — 06's hazard, checked by
  `docker inspect` and not the dashboard.
- qbittorrent's own egress is `94.140.8.185` (Seattle) against the host's
  `75.155.182.130`. The tunnel carries it, not the bridge.
- gluetun's settings summary prints `Firewall: enabled` and **no outbound
  subnets**. The kill switch is gluetun's own default, still in force.
- `gluetun:30024` answers `v5.1.2` from sonarr, from homepage and through
  `https://qbittorrent.rbrb.in`; sonarr's and radarr's download clients still
  hold `192.168.1.195` and neither reports a health failure.

### The rollback, unused

Portainer's `/mnt/user/appdata/portainer/compose/2/docker-compose.yml` still
describes the pair as it ran, and appdata was copied to
`/mnt/user/appdata/backup-24-{qbittorrent,gluetun}` (21M) first. **Delete those
two directories once a week has passed without a rollback.** Rolling back means
dropping `download` from the deploy pattern first, or the next reconcile takes
the containers straight back.

### `latest` pinned nothing, on both images — but only one had a lift available

`qmcgaw/gluetun:latest` on the box was a **master build**, `fdf049f8`, from
2025-11-16: between `v3.40.1` and `v3.40.2` and carrying 3.41's DNS renames
before 3.41 existed. No tag reproduces it, so there was no "adopt unchanged"
option — only a choice of which release to land on. **`v3.41.3`**, the current
one: landing on a nine-month-old release buys nothing but old code, and
Renovate's `stacks/download/**` rule would have raised the same bump for a human
to merge with nobody watching. Doing it in the window where someone was watching
is the cheaper end of the same decision.

qbittorrent was the other case: `5.1.2-r4-ls426` **is** the digest that was
running, so its pin is a true lift and nothing about it changed but `TZ`, which
was `UTC` because Portainer's `.env` never set it and is now `America/Vancouver`
from [common.env](../../../common.env).

### Four cargo variables, not two

The ticket warned about two misspelled firewall variables. There were four
variables gluetun does not read at all — `FIREWALL_OUTBOUND_SUBNET`,
`FIREWALL_VPN_INPUT_ALLOW`, `VPN_WAIT` and `VPN_WAIT_TIME` — and the settings
summary proves the point: it lists no outbound subnets, so the `0.0.0.0/0` never
applied.

**Dropped, not carried verbatim**, which reverses this ticket's own instruction.
Carrying them was meant to stop someone correcting the spelling; but the same
reader who would "fix" `FIREWALL_OUTBOUND_SUBNET` can only do so if the line is
there to fix. Absence plus a comment saying *why* it is absent is the stronger
guard, and it is behaviourally identical — verified, not argued, since gluetun's
own summary shows the empty default in force. The rule went to
[docs/adding-a-service.md](../../../docs/adding-a-service.md) as step 6b: diff
the container's env against the **image's**, and drop what the image does not
declare. That is 22's finding earned a second time.

### 6881 is gone; the router forwards it no more than it forwards 30024

Probed from outside both networks: `75.155.182.130:6881` and `:30024` both time
out. Only 32400 is forwarded ([31](31-plex-own-internet-exposure.md)), so
publishing the torrent port bought nothing — peers arrive through the tunnel or
not at all. `30024` stays until [30](30-arr-urls-on-shared.md) repoints the four
*arr; it is the last host port on this Stack.

### `bypass_auth_subnet_whitelist`, and the setting that accepts anything

`AuthSubnetWhitelist` gained `172.20.0.0/16` through qbittorrent's own API, so
qbittorrent wrote its own config rather than an edit racing the container's exit.
The trap: the preference is **`bypass_auth_subnet_whitelist`**, and the name that
matches the config file — `web_ui_auth_subnet_whitelist` — returns **HTTP 200 and
changes nothing**. `setPreferences` validates no key it does not know. Read the
value back before believing it.

`172.18.0.0/16` is still in the list. It is the old `qbittorrent_default` subnet
and it is only there so a rollback works; **30** should drop it when it drops the
host port.

Consequence, stated plainly: every container on `shared` can now drive
qbittorrent's API unauthenticated, which is what homepage's credential-free
widget has always relied on [08]. Through Caddy the source address is the bridge
gateway, so `https://qbittorrent.rbrb.in` is unauthenticated for anyone the
`(internal)` guard admits — LAN and tailnet. That is not new; it is the same
posture the published port already had, and it belongs to the auth fog, not here.

### Komodo's database holds the plaintext WireGuard key

`grep -rl` over appdata finds it in `komodo/postgres/data/` — the Stack that
[11](11-stand-up-komodo.md) adopted stored its compose file, key and all, in
Komodo's own database. The Stack is repo-backed now, but the old tuples survive
until a vacuum. So [25](25-retire-portainer.md)'s disposition question has a
second subject, and the map's **appdata backup** fog has a sharper edge: a backup
of Komodo's database is a backup of a secret.

The decrypted `secrets.env` on the box is `0600`, as [19](19-secret-hygiene-on-the-box.md)
requires. `/mnt/user/appdata/komodo/adopt/download/` is deleted.
