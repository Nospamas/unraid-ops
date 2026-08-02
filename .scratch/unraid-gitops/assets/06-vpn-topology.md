# qbittorrent VPN topology — what the repo encodes

Asset for [06 — Decide the qbittorrent VPN topology](../issues/06-qbittorrent-vpn-topology.md).
Facts checked against gluetun's wiki (August 2026) and against the container
environment captured in [01](01-inventory.md).

## Verdict

| | |
|---|---|
| Topology | **gluetun sidecar, adopted unchanged** — `network_mode: service:gluetun` |
| Provider | **NordVPN stays.** No port forwarding, by choice |
| *arr → qbittorrent | **Shared user-defined network**, addressed `http://gluetun:30024` |
| Firewall vars | **Both existing ones are typos. Drop them — do not "fix" them** |
| Kill switch | Sound as it stands, for a reason the running config did not intend |

## What actually goes through the tunnel

Stated explicitly by the human, because it is the constraint everything below
serves: **only qbittorrent's torrent-related traffic is tunnelled.** Every UI and
every other HTTP flow stays ordinary LAN or tailnet traffic. "Torrent-related" is
the load-bearing word — it is wider than peer traffic, and the table below is
what it covers.

The adopted topology already delivers this, and it is worth being precise about
why, because "qbittorrent is in the VPN namespace" sounds like it should tunnel
more than it does.

| Flow | Path | Tunnelled? |
|---|---|---|
| qbittorrent → peers, DHT | gluetun's `tun`, the only route out | **Yes** |
| qbittorrent → trackers (HTTP/S announces) | same | **Yes**, by design — see below |
| Browser → qbittorrent WebUI | docker publish on host `30024` | No — local |
| *arr → qbittorrent API | shared docker network, `gluetun:30024` | No — local |
| Caddy → qbittorrent WebUI | same shared network | No — local |
| sonarr, radarr, plex, calibre… everything else | ordinary bridge networks | No — never touched gluetun |

Two things to be unambiguous about:

- **Tracker announces are HTTP and they do go through the tunnel.** That is
  correct — they are torrent traffic, and they are the flow that would expose the
  box's real IP if it leaked. "HTTP stays local" means *service UIs*, not
  everything that speaks HTTP.
- **Everything qbittorrent itself initiates is tunnelled** — RSS feeds, search
  plugins, its DNS lookups (gluetun runs a DoT resolver in the namespace). This
  is inherent to namespace sharing and is the desired posture; there is no
  split-tunnel inside the container and no way to ask for one.

Nothing else on the box is behind gluetun. The other seven workloads sit on
normal bridge networks and are entirely unaffected by the VPN's state — if the
tunnel drops, plex and the *arr UIs carry on.

## The provider: NordVPN stays, seeding stays crippled

NordVPN offers no port forwarding on any plan, so no gluetun setting recovers
it. The consequence is asymmetric and worth stating plainly: **outbound peer
connections work, inbound ones do not**. Downloads still complete — qbittorrent
reaches out to seeds — but nothing reaches in, so the client is effectively
leech-only. On public trackers this costs swarm speed on thinly-seeded torrents.
On a private tracker it means ratio only ever falls.

The human ruled this acceptable rather than buy a second subscription. Recorded
so it is a known posture rather than a latent bug someone rediscovers.

### What a reversal would cost, if ratio ever matters

gluetun has **native** port forwarding for exactly four providers: Private
Internet Access, ProtonVPN, Perfect Privacy and PrivateVPN. **AirVPN is
supported as a provider but has no native port-forwarding integration** — a
common misconception worth pinning, since it is usually named alongside PIA and
Proton in port-forwarding advice.

Switching to Proton or PIA would mean, roughly in order:

- A new subscription and a **new `WIREGUARD_PRIVATE_KEY`**, replacing the NordVPN
  one in the SOPS set from [03](../issues/03-secrets-handling.md). Note in
  passing: this would retire the leaked key as a side effect. It is *not* a
  reason to switch, and per the map's Secret severity note rotation is not being
  chased.
- Server filtering by `PORT_FORWARD_ONLY=on` — not every server forwards.
- `VPN_PORT_FORWARDING=on`, plus an **up/down command pair** pushing the port
  into qbittorrent, because the port is assigned dynamically per connection:

  ```
  VPN_PORT_FORWARDING_UP_COMMAND=/bin/sh -c 'wget -O- -nv --retry-connrefused \
    --post-data "json={\"listen_port\":{{PORT}},\"random_port\":false,\"upnp\":false}" \
    http://127.0.0.1:30024/api/v2/app/setPreferences'
  ```

- qbittorrent's **"bypass authentication for clients on localhost"** must be on,
  or the command above is rejected. That is a setting in qbittorrent's own
  config, which lives in appdata and is **not** git-owned.
- The status file `/tmp/gluetun/forwarded_port` still exists but is **deprecated
  since gluetun v4.0.0**; the commands and the control server are the current
  interface. Anything written against the file is following stale advice.

Proton renegotiates its port roughly every 60 seconds and it can change across
reconnects, so the up-command is not a one-shot — it is the mechanism.

## The two firewall variables are typos, and the typo is load-bearing

The running stack sets:

```
FIREWALL_VPN_INPUT_ALLOW=192.168.1.0     # not a gluetun variable
FIREWALL_OUTBOUND_SUBNET=0.0.0.0/0       # not a gluetun variable (singular)
```

Neither exists. gluetun's real variables are `FIREWALL_VPN_INPUT_PORTS`,
`FIREWALL_INPUT_PORTS` and `FIREWALL_OUTBOUND_SUBNETS` (plural) — and the
inventory confirms all three are sitting at their empty defaults in the running
container. So both lines have been doing nothing for as long as they have been
there.

**Do not translate them into their "correct" forms.** `FIREWALL_OUTBOUND_SUBNETS`
means *subnets gluetun and its namespace-sharers may reach outside the tunnel*.
Setting it to `0.0.0.0/0` — the evident intent — would permit **all** traffic to
bypass the VPN, which is precisely the hole the kill switch exists to close. The
typo is the only reason that never happened. Fixing the spelling while keeping
the value would silently disable the protection the stack is built around.

`FIREWALL_VPN_INPUT_ALLOW=192.168.1.0` looks like an attempt to admit the LAN. It
is unnecessary, and it is also malformed twice over — the real variable takes
*ports*, not subnets, and `192.168.1.0` is a bare address rather than CIDR.

### Why dropping them does not cost local access

This is the question the "UIs stay local" requirement raises, so it is worth
settling rather than assuming. `FIREWALL_OUTBOUND_SUBNETS` governs **one
direction only**: a container *inside* the namespace initiating a connection
*outward* to a LAN subnet. The canonical case is an app behind the VPN needing to
call a service on the LAN.

qbittorrent never does this. Every local flow it takes part in is **inbound** —
the browser, the four *arr and later Caddy all initiate, and replies ride back on
established connections. Inbound to a published port is handled by docker's port
mapping before gluetun's outbound policy is consulted at all, which is why the
WebUI is LAN-reachable today with all three real firewall variables empty. The
inventory observed exactly that.

**Both lines are dropped when the stack moves into git.** Nothing replaces them,
and local access is unaffected.

If some future service behind the tunnel genuinely does need to reach out to the
LAN, the safe value is the **specific subnets** —
`FIREWALL_OUTBOUND_SUBNETS=192.168.1.0/24,100.64.0.0/10` for LAN plus tailnet —
and never `0.0.0.0/0`, which is the whole-kill-switch hole described above. Note
the format trap: it must be a network address in CIDR (`192.168.1.0/24`), not a
host address, or gluetun exits at startup.

## Kill switch: sound

Three facts together, all confirmed:

- `FIREWALL_ENABLED_DISABLING_IT_SHOOTS_YOU_IN_YOUR_FOOT=on` (the default). When
  the tunnel is down, gluetun's firewall blocks egress; connected apps see
  `operation not permitted` rather than leaking to the open internet.
- qbittorrent has **no network interface of its own** — it shares gluetun's
  namespace entirely. There is no second path for it to leak down, so this is
  structural rather than configuration-dependent.
- `HEALTH_RESTART_VPN=on` (the default) restarts **the VPN process inside the
  container**, not the container. gluetun's internal health monitor is distinct
  from the Docker healthcheck. The network namespace survives, so qbittorrent
  keeps its networking across an auto-heal.

One caveat found in gluetun's own issue tracker: after an internal VPN restart,
forwarded-port firewall rules are not always re-established. It does not apply
here — nothing is forwarded — but it would become live the moment a provider
switch happens.

## The namespace hazard, which GitOps makes sharper

Restarting the VPN is safe. **Recreating the gluetun container is not.** A
container joined with `network_mode: service:gluetun` is bound to a specific
namespace instance; when gluetun is recreated, that namespace is destroyed and
the dependent keeps pointing at the dead one. qbittorrent does not crash — it
sits there with no network until it is *itself* recreated.

Today this only bites on manual intervention. Under Komodo it becomes routine:
**any push that changes the gluetun service recreates it**, and `compose up` does
not recreate unchanged dependents by default. The failure is silent and looks
like "downloads mysteriously stopped" hours later.

So whatever migrates this stack must guarantee gluetun and qbittorrent are
**recreated together** — same compose project, and a deploy that forces the
dependent down with it. Whether Komodo's Deploy action does this on its own is
unverified and must be tested on the box, not assumed. Pausing and unpausing is
specifically *not* enough; only a full recreate rejoins the namespace.

## How the *arr reach qbittorrent

Today the only path is the host, `192.168.1.195:30024`, because sonarr, radarr,
prowlarr and lazylibrarian sit on the default bridge (172.17.0.0/16) while
gluetun is on `qbittorrent_default` (172.18.0.0/16).

**Decision: a shared user-defined network, declared in git.** gluetun and the
four *arr join it, and the download client is addressed by container name. This
keeps a LAN address that the box could change out of the repo entirely.

Consequences to carry into the migration:

- **The address is `http://gluetun:30024`, not `qbittorrent`.** qbittorrent has
  no name on any network — the namespace owner is what DNS resolves. The port is
  30024 inside the namespace too (`WEBUI_PORT=30024`), so it is the same number
  on both sides of the move.
- **Komodo runs each stack as its own compose project**, so a network spanning
  stacks has to be `external: true` in every stack that references it, and
  created once by something outside them. Where that declaration lives is
  [07](../issues/07-repo-layout-and-conventions.md)'s call — flagged to it.
- **Each *arr's download-client setting lives in its appdata database, not git.**
  Changing the host to `gluetun` is a one-time manual edit in four UIs, and it is
  the one step of this that a `git push` cannot perform. Sequence it after the
  network exists, or imports break in the gap.
- **Verify, do not assume, that gluetun admits the new subnet.** The expectation
  is that it does — gluetun auto-allows its directly-attached subnets, which is
  how the published port works now. If a connection from an *arr is refused, the
  fix is `FIREWALL_INPUT_PORTS=30024`, not disabling anything.
- **Keep the host publish of 30024** for now. It is how a human opens the WebUI,
  and [05](../issues/05-remote-access.md)'s default-deny keeps it at LAN +
  tailnet. Caddy from [04](../issues/04-reverse-proxy-and-domain.md) can front it
  over the same shared network once it exists.

Auth in front of the WebUI is untouched by this. It remains what
[05](../issues/05-remote-access.md) left it: fog, live only once something is
actually published.

## Loose end

`ghcr.io/bubuntux/nordvpn:get_private_key` (3 years old) was one-shot tooling for
generating the WireGuard key. The key exists; **nothing needs the image**. Delete
it alongside the other stale images when Portainer is removed — it is untracked
cruft, not a dependency.

## Sources

- [gluetun firewall options](https://github.com/qdm12/gluetun-wiki/blob/main/setup/options/firewall.md)
- [gluetun VPN port forwarding](https://github.com/qdm12/gluetun-wiki/blob/main/setup/advanced/vpn-port-forwarding.md)
- [gluetun ProtonVPN provider setup](https://github.com/qdm12/gluetun-wiki/blob/main/setup/providers/protonvpn.md)
- [gluetun healthcheck FAQ](https://github.com/qdm12/gluetun-wiki/blob/main/faq/healthcheck.md)
- [gluetun #641 — connectivity lost once gluetun is restarted](https://github.com/qdm12/gluetun/issues/641)
- [gluetun #3260 — port forwarding forces qbittorrent restart](https://github.com/qdm12/gluetun/issues/3260)
