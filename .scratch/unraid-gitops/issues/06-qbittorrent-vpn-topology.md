# 06 — Decide the qbittorrent VPN topology

Type: research
Status: closed
Assignee: Nospamas
Resolved: 2026-08-01
Asset: [assets/06-vpn-topology.md](../assets/06-vpn-topology.md)

## Question

**The topology question is largely already answered.**
[01 — Inventory the containers already running on the box](01-inventory-running-containers.md)
found the gluetun sidecar pattern already running: `qbittorrent` has
`network_mode: service:gluetun`, gluetun holds `CAP_NET_ADMIN` and publishes the
WebUI on host port 30024 and torrent traffic on 6881 tcp+udp. The alternatives
originally listed here — a VPN-enabled qbittorrent image, host-level routing —
would be a *regression* from what exists. Adopt the existing topology unless
something below forces otherwise.

What actually remains open:

- **The provider.** It is NordVPN over WireGuard, pinned to `us8240.nordvpn.com`
  (Seattle), with `VPN_PORT_FORWARDING=off`. NordVPN offers no port forwarding
  at all, so **seeding is already crippled and no config change fixes it** — the
  only fix is a different provider (ProtonVPN, AirVPN and PIA are the usual
  port-forwarding options, all supported by gluetun). Decide whether that
  matters enough to switch. This is now the ticket's central question, and it is
  a judgement call about ratio and tracker requirements, not a technical one.
- **How the *arr services reach qbittorrent.** Today they cannot do it by
  container name: sonarr/radarr sit on the default `bridge` network
  (172.17.0.0/16) while gluetun is on `qbittorrent_default` (172.18.0.0/16), so
  the only path is the host at `192.168.1.195:30024`. Decide whether the repo
  encodes that host-IP indirection, or puts the *arr on a shared user-defined
  network with gluetun so a container name resolves. The latter is tidier and
  removes a hard-coded LAN address from git.
- **Two firewall variables in the running stack look like no-ops.**
  `FIREWALL_VPN_INPUT_ALLOW=192.168.1.0` and `FIREWALL_OUTBOUND_SUBNET=0.0.0.0/0`
  are set, but gluetun's real variables (`FIREWALL_INPUT_PORTS`,
  `FIREWALL_OUTBOUND_SUBNETS` — plural) are empty in the container's actual
  environment. Confirm against gluetun's docs before the repo copies them
  forward; if they are typos, the current kill-switch posture is not what was
  intended.
- **Kill-switch behaviour** — what happens to torrent traffic when the tunnel
  drops. `FIREWALL_ENABLED_...=on` and `HEALTH_RESTART_VPN=on` are set; confirm
  that qbittorrent cannot leak during a gluetun restart, given it shares the
  namespace.
- **Whether the proxy from ticket 04 can reach the WebUI** through the same
  indirection. Note the WebUI currently binds `0.0.0.0:30024` with no auth in
  front of it beyond qbittorrent's own.
- The stale `ghcr.io/bubuntux/nordvpn:get_private_key` image on the box is
  leftover key-generation tooling; note whether anything still needs it.

Write the comparison as an asset only where a real choice remains — chiefly the
provider. The answer names the provider, whether port forwarding is being bought,
and how the *arr address qbittorrent.

## Answer

Full detail in [assets/06-vpn-topology.md](../assets/06-vpn-topology.md).

**The topology is adopted unchanged** — gluetun sidecar,
`network_mode: service:gluetun`. Nothing below alters it.

**Scope of the tunnel, stated by the human: only qbittorrent's torrent-*related*
traffic goes through NordVPN.** Every service UI and all other HTTP stays
ordinary LAN or tailnet traffic. **The current setup already does exactly this** — this is a
constraint to preserve, not a change to make. Two clarifications so it is not
misread later: tracker announces are HTTP and *are* tunnelled, correctly, because
they are torrent traffic; and everything qbittorrent itself initiates (RSS,
search plugins, DNS) is tunnelled too, inherently, because namespace sharing
admits no split tunnel. Nothing else on the box is behind gluetun at all.

**Provider: NordVPN stays. Port forwarding is not being bought.** The human ruled
the ratio cost acceptable rather than take on a second subscription, so
qbittorrent is knowingly **leech-only**: outbound peer connections work, inbound
ones never will. This is a settled posture, not a defect — do not re-open it as a
finding. gluetun has native port forwarding for exactly four providers (PIA,
ProtonVPN, Perfect Privacy, PrivateVPN — **AirVPN is not among them**, despite
being commonly named); the asset records what a reversal would cost so it does
not need researching twice.

**Both firewall variables are typos, and one of them is load-bearing.**
`FIREWALL_VPN_INPUT_ALLOW` and `FIREWALL_OUTBOUND_SUBNET` are not gluetun
variables at all, and the real ones (`FIREWALL_INPUT_PORTS`,
`FIREWALL_OUTBOUND_SUBNETS`) sit empty in the running container. **They are
dropped, not corrected** — spelling `FIREWALL_OUTBOUND_SUBNETS=0.0.0.0/0`
properly would let all traffic bypass the tunnel, which is the exact hole the
kill switch closes. The typo is the only reason that never happened. Dropping
them costs no local access: that variable only governs a container *inside* the
namespace initiating *outward* to the LAN, and qbittorrent never does — every
local flow it takes part in is inbound, which docker's port mapping and the
shared network handle before gluetun's outbound policy applies. If a future need
does arise, the safe value is the specific LAN + tailnet CIDRs, never
`0.0.0.0/0`.

**The kill switch is sound.** `FIREWALL_ENABLED_...=on` blocks egress when the
tunnel drops; qbittorrent has no interface of its own to leak down, so this is
structural; and `HEALTH_RESTART_VPN=on` restarts the VPN *process*, not the
container, so the namespace survives an auto-heal.

**New hazard, sharpened by GitOps: recreating gluetun orphans qbittorrent.** A
namespace-sharing container is bound to one namespace instance; recreate gluetun
and qbittorrent silently keeps pointing at the dead one — no crash, just no
network until it is itself recreated. Under Komodo this stops being a manual-only
event: any push touching gluetun recreates it, and `compose up` does not recreate
unchanged dependents. Whatever migrates this stack must recreate the pair
together, and **whether Komodo's Deploy does that unaided is unverified** — test
it on the box.

**The *arr reach qbittorrent over a shared user-defined network**, addressed
`http://gluetun:30024` — the namespace owner is what resolves, not
`qbittorrent`, and 30024 is the port on both sides. This keeps the box's LAN
address out of git. Three consequences carried forward: the network must be
`external: true` across stacks because Komodo runs each as its own compose
project (flagged to [07](07-repo-layout-and-conventions.md)); each *arr's
download-client host is an appdata setting, so it is **a one-time hand edit in
four UIs** that no push can perform; and gluetun's admission of the new subnet is
expected but must be verified, with `FIREWALL_INPUT_PORTS=30024` as the fallback.

The host publish of 30024 stays, LAN + tailnet only per
[05](05-remote-access.md). Auth in front of the WebUI is untouched and remains
fog. The stale `ghcr.io/bubuntux/nordvpn:get_private_key` image is needed by
nothing — delete it with the other cruft when Portainer goes.

## Addendum, 2026-08-05 — the server pin is load-bearing

This ticket recorded `us8240.nordvpn.com` as inherited state and never said why a
single server was named. **It is a constraint: the trackers in use bind a session
to the exit IP, so the tunnel may not float across Seattle.** The exit IP is a
property of the server and holds for as long as the server does, so a hostname
pin is what buys it. Stated by the human after `us8240` failed, and written down
here because nothing in the repo carried it — the obvious repair at the time,
dropping the pin so gluetun picks any Seattle server, would have quietly cost the
thing the pin existed to protect.

NordVPN decommissioned `us8240` on 2026-08-04 and the stack ran dead for 34 hours
before anyone noticed. Two properties of that failure are worth keeping:

- **It is silent.** WireGuard does not report a dead peer. gluetun kept dialling
  the cached IP and the only symptom was the healthcheck's DNS timeouts, i.e. it
  looks like a DNS fault and is not one.
- **The kill switch held throughout.** Verified from inside the namespace:
  qbittorrent had no outbound path for the whole window. A dead pin stalls
  downloads, it does not leak them.

**Replacing the pin has two conditions, and the second is not obvious.** The
server must be P2P (`legacy_p2p` in NordVPN's API — the group is per-server, not
per-city), *and* it must appear in gluetun's own bundled server list. Of 135 live
Seattle P2P WireGuard servers, **65 exist in gluetun's list**, all with IPs still
matching the API's. Pinned `us9983.nordvpn.com` (193.29.61.84) from that
intersection. Avoid `212.102.4x` — `us8240`'s own block, being retired, though
`us8275`–`us8281` still resolve.

**The stale list is upstream, not ours, and no image bump fixes it.** v3.41.3 is
the latest release and the box already runs it; the bundled NordVPN section is
stamped **2024-03-21** while sibling providers were refreshed into 2026 (PIA
2026-04, airvpn 2026-03) — NordVPN alone has been left behind. The
`/gluetun/servers.json` in appdata is byte-identical to the image's bundle
(md5 `45d678460a144e775753f03a8b5618ab`), so there is nothing local to clear
either: gluetun merges the two and the bundle wins. Checked against the source,
which has since moved from `qdm12/gluetun` to `passteque/gluetun` — the image
stays digest-pinned regardless.

**What that costs is hardware age, which is the same axis that just failed.**
A bundle built 2024-03 can only name servers built before it, so the 65 pinnable
ones are the 2022 cohort (55), 2020 (7) and 2021 (3). Every one of the 70 live
servers it cannot name is newer: 2026 (50) and 2024 (20). The pin is therefore
necessarily on ≤2022 hardware, and NordVPN is visibly retiring old cohorts —
that is what `us8240` was.

**Querying NordVPN for a replacement — two silent traps.** The list comes from
`https://api.nordvpn.com/v1/servers`, undocumented but the same source gluetun's
own updater uses. Filter server-side and pass `limit=0`:

```
curl -s "https://api.nordvpn.com/v1/servers" -G \
  --data-urlencode "filters[servers_technologies][identifier]=wireguard_udp" \
  --data-urlencode "filters[servers_groups][identifier]=legacy_p2p" \
  --data-urlencode "limit=0"
```

`limit=<n>` **caps and does not say so** — `limit=8000` returns exactly 8000 of
8580, so a server absent from that response is not thereby retired. And
`filters[servers.hostname]` is **ignored, not rejected**: it returns a normal
200 with unrelated servers, so checking one hostname that way reads as a
confident wrong answer. Match hostnames client-side against the full set
instead. Cross-check a retirement against DNS — a decommissioned host stops
resolving, which is what confirmed `us8240` first.

**`UPDATER_PERIOD` is the way off that, and it takes two steps, not one.** With
it set, gluetun refreshes `servers.json` from NordVPN's live API (the updater
ships in v3.41.3 at `internal/provider/nordvpn/updater`) and persists it to
appdata. It cannot be done in a single move: the updater only runs once the
tunnel is up, and the tunnel needs a pin gluetun can already resolve. So —
pin a ≤2022 server first, let the refresh land, *then* repin onto the 2026
cohort.

**Both steps ran on 2026-08-05.** `us9983` restored service at 12:41 and the
first updater tick landed at 12:46, rewriting `servers.json` from 11548 entries
stamped 2024-03-21 to 17105 stamped that afternoon — Seattle WireGuard went 114
→ 185, matching the live API exactly. Repinned onto `us13886.nordvpn.com`
(187.15.91.11, provisioned 2026-07-29) and dropped the period to 24h. `us8240`
is now absent from gluetun's own list, which is the point: with the list
current a retired pin makes gluetun refuse an unknown hostname at startup
instead of silently dialling a corpse.

Exit IPs, since trackers bind to them: `94.140.8.185` (us8240, dead) →
`157.97.134.176` (us9983, transitional) → whatever `us13886` resolves to. The
entry IP in the logs is never the exit IP — do not read the `wireguard
Connecting to ...` line as the address a tracker sees.

Two follow-ups this leaves open, neither taken here: nothing probes the tunnel,
which is why 34 hours passed unnoticed ([29](29-alerting-on-failed-reconcile.md)
owns the alerting path); and gluetun's `UPDATER_PERIOD` is unset, which is what
makes a retired pin fail silently rather than loudly — with the list fresh,
gluetun would refuse to start on an unknown hostname instead of dialling a
corpse. Both are judgement calls about noise, not defects.
