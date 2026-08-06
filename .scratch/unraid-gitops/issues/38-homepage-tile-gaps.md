---
id: "38"
title: Close the homepage tile gaps
type: task
status: closed
description: >
  All four tiles are on the dashboard. Only gatus held a decision: it is
  host-networked, so it has no name on `shared`, and it dials
  `host.docker.internal` — the box's LAN IP is a DHCP lease git cannot own,
  and `status.rbrb.in` would be 403'd by the guard for arriving from a bridge.
touches: [stacks/homepage/config/services.yaml, stacks/homepage/compose.yaml]
---

# 38 — Close the homepage tile gaps

Resolved: 2026-08-06
Blocked by: 35, 36

## Question

Four services on this box have no tile, one tile points at a service being
removed, and the dashboard is the thing rb is meant to open first. Close the
factual gaps, so that [39](39-rework-homepage-dashboard.md) opens on a complete
set rather than spending its session on data entry.

**The removal half is done** — [25](25-retire-portainer.md) took the tile and
`HOMEPAGE_VAR_HOST` with it rather than leaving a dead tile on the dashboard
while this ticket waited behind 35 and 36. What is left here is the four
additions.

**Nothing here is a taste decision.** Layout, grouping, theme and what deserves a
widget are 39's, deliberately.

### Missing entirely

[29](29-alerting-on-failed-reconcile.md) built two services and never put either
on the dashboard:

- **gatus** — `status.rbrb.in`, the one thing that knows whether all eleven
  probes pass. Homepage ships a `gatus` widget type.
- **ntfy** — `ntfy.rbrb.in`. Homepage ships an `ntfy` widget. **Use the hostname,
  not `:8095`**: the port is the alert path for publishers and the phone, and
  pointing a browser at the hostname is exactly what that door is for.

Plus the two this map adds — **tautulli** and **bazarr**. Tautulli's widget is
the valuable one; it shows both current playback and history, and may make
plex's own `enableNowPlaying` redundant.

### Removed already, by [25](25-retire-portainer.md)

The Portainer tile, the `HOMEPAGE_VAR_HOST` variable in
[stacks/homepage/compose.yaml](../../../stacks/homepage/compose.yaml), and the
comment in
[config/services.yaml](../../../stacks/homepage/config/services.yaml) that
promised it. The variable was the box's raw LAN IP, which
[26](26-host-state-scope.md) ruled git cannot own because it is a DHCP lease in
rb's router. **Do not give it a second reader** — none of the four tiles below
needs one.

### The conventions the file already states

Every `href` is `https://<name>.rbrb.in`; every widget `url` is
`http://<service>:<port>` across `shared`; `container:` reads state through the
dockerproxy Stack and names the **compose** container, which is
`<project>-<service>-1` and where the project name may not match the Stack name
— plex and qbittorrent both inherited Portainer's.

### Do not forget

- New widgets need API keys as `HOMEPAGE_VAR_*` in
  [secrets.sops.env](../../../stacks/homepage/secrets.sops.env) — `just secret
  homepage`, never `sops --encrypt`.
- Homepage's config is git-owned and listed in `config_files`; a push that edits
  one is only picked up because it is listed. Check any new file is.

## Answer

All four tiles are on the dashboard. Three of the four were the data entry this
ticket was written to be — **gatus was the only one holding a decision.**

Placement is by what each service reads: tautulli after plex, bazarr after
radarr, gatus and ntfy in Infrastructure. That is adjacency, not grouping —
grouping stays [39](39-rework-homepage-dashboard.md)'s.

### gatus has no name to dial, and three of the four addresses are wrong

Host networking [29] means gatus is on no docker network, so the file's own
convention — `http://<service>:<port>` across `shared` — has nothing to name.
Every alternative but one is a trap:

| address | why not |
|---|---|
| `http://192.168.1.195:8090` | the LAN IP is a DHCP lease in rb's router, which [26](26-host-state-scope.md) rules git cannot own. It is the `HOMEPAGE_VAR_HOST` this ticket was told not to give a second reader |
| `https://status.rbrb.in` | two failures at once — homepage's resolver is the router, which strips `rbrb.in` answers [32], and a request from the bridge reaches host-networked Caddy as `172.20.x.x`, outside the guard's ranges. **This is the same trap that put gatus itself on CoreDNS** [29] |
| `http://172.20.0.1:8090` | works, and answered 200 when tested — but the `shared` subnet is docker's default-pool allocation, created by `docker network create shared` with no subnet declared. A recreate moves it |
| `http://host.docker.internal:8090` | taken |

`extra_hosts: - "host.docker.internal:host-gateway"` in
[compose.yaml](../../../stacks/homepage/compose.yaml) is the one spelling with
no literal in it: docker resolves `host-gateway` at container-create time, to
`172.17.0.1` on this box. gatus binds `0.0.0.0:8090`, so it answers there.

**It is homepage's only widget off `shared`, and the comment says so** — the
convention at the top of the file is otherwise unqualified, and a bare
`host.docker.internal` in a list of container names reads as a mistake.

### What the widgets actually take

Read off the docs rather than assumed, and two of the four came back different
from what this ticket expected:

- **gatus takes no key.** `type` and `url`, nothing else. No hand-off.
- **ntfy requires `topic`** — not optional. `tower`, the topic gatus and Komodo
  already publish to. No credentials: no ntfy accounts exist [29].
- **tautulli and bazarr take `key`**, as expected. These are the hand-off.

So the ticket's "expect one hand-off" was right in shape and half right in
size — gatus and ntfy went live on deploy.

### Verified, not assumed

`just reconcile` was green, which [CLAUDE.md](../../../CLAUDE.md) says proves
nothing:

| check | result |
|---|---|
| homepage recreated carrying `extra_hosts` | `[host.docker.internal:host-gateway]`, resolving to `172.17.0.1` |
| all four widget upstreams, dialled from inside homepage | 200 — `ntfy:80/v1/health`, `tautulli:8181/status`, `bazarr:6767/api/system/ping`, `host.docker.internal:8090/api/v1/endpoints/statuses` |
| config parsed | no error in homepage's log; a bad `services.yaml` logs one |
| all four tiles live in the running config | see below |

**The obvious check does not work.** Homepage renders its tiles client-side, so
fetching `home.rbrb.in` and grepping for `Tautulli` finds nothing — and finds
nothing for `Sonarr` either, which has worked for months. Absence proves nothing
there.

What does prove it is `/api/services/proxy`, with a control: a service homepage
does not know answers `Unknown proxy service type`, while a known-good Sonarr
answers `Unsupported service endpoint`. All four new tiles answer **exactly what
Sonarr answers**, so homepage resolved each one to a widget in its live config.

### Left alone for 39

Plex's `enableNowPlaying: true` may now be redundant beside tautulli's widget,
which shows the same streams. **Deliberately not touched** — that is "what
deserves a widget", which this ticket handed to 39 on purpose.

## Hand-offs

One, exactly as expected, and narrower: **the tautulli and bazarr API keys.**
Until they land, those two widgets show an error; their tiles and links work,
and gatus's and ntfy's widgets are already live.

Reading the keys off the box directly was attempted and refused by tooling, so
they come out of the two UIs: tautulli at *Settings → Web Interface → API*,
bazarr at *Settings → General*. Then `just secret homepage`, adding
`HOMEPAGE_VAR_TAUTULLI_KEY` and `HOMEPAGE_VAR_BAZARR_KEY` beside the four
already there.

**Both keys are regenerated if the service's appdata is rebuilt**, which is the
concrete instance of the fog this map already carries about git and appdata.
