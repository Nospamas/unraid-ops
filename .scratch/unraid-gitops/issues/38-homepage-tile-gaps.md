# 38 — Close the homepage tile gaps

Type: task
Status: open
Blocked by: 25, 35, 36

## Question

Four services on this box have no tile, one tile points at a service being
removed, and the dashboard is the thing rb is meant to open first. Close the
factual gaps, so that [39](39-rework-homepage-dashboard.md) opens on a complete
set rather than spending its session on data entry.

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

### To remove

The **Portainer** tile, with [25](25-retire-portainer.md). It is the **last
reader of `HOMEPAGE_VAR_HOST`** — the box's raw LAN IP, which
[26](26-host-state-scope.md) ruled git cannot own because it is a DHCP lease in
rb's router. Remove the variable from
[stacks/homepage/compose.yaml](../../../stacks/homepage/compose.yaml) in the same
change, and delete the comment in
[config/services.yaml](../../../stacks/homepage/config/services.yaml) that promises
it. **Do not give it a second reader.**

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

## Hand-offs

Expect one — collecting the tautulli and bazarr API keys out of their UIs.
