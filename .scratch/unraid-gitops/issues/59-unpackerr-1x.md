---
id: "59"
title: Land unpackerr 1.x
type: task
status: closed
description: >
  Renovate's 1.x bump merged with no Stack changes, but 1.x answers /metrics only
  to an API key, dropped the container's implicit poll, and mints a new UI
  password per recreate without /config. gatus now holds a key scoped to
  system:metrics:read, the poll is explicit, and git stays the only config.
touches:
  - stacks/unpackerr/compose.yaml
  - stacks/unpackerr/secrets.sops.env
  - stacks/gatus/compose.yaml
  - stacks/gatus/komodo.toml
  - stacks/gatus/secrets.sops.env
  - stacks/gatus/conf/config.yaml
  - docs/adding-a-service.md
  - docs/conventions.md
---

# 59 — Land unpackerr 1.x

Resolved: 2026-11-01
Blocked by: —

## Question

What does `ghcr.io/unpackerr/unpackerr:v1.0.1` need from this Stack before it
replaces 0.16.1? The bump changed one line and would have deployed at 3am.

## Resolution

Read from upstream's
[upgrade guide](https://unpackerr.zip/docs/install/upgrading/) and the source at
the image's revision, `f58fab2`.

- **`/metrics` takes only an API key.** Sessions and `noauth` are ignored. The
  key is `UN_WEBSERVER_API_KEYS_0_*` with a one-permission role, and gatus gained
  its first secret to send it.
- **The poll is explicit.** `UN_FOLDER_0_INTERVAL: 1s`. The implicit poll is gone,
  and whether fsnotify alone sees writes on shfs was not tested: upstream says to
  poll a bind mount, and watching this folder is the Stack's purpose [48].
- **No `/config`, deliberately.** It would make the UI's file a second source of
  configuration. The cost is that Save has nowhere to write and queue history
  dies with the container. Without `UN_WEBSERVER_UI_PASSWORD` every recreate
  prints a fresh password to the log; the in-memory admin API key is still
  generated each start and is unused.
- **The entrypoint survives.** The docs' `FROM scratch` describes golift's image.
  The ghcr image is Alpine, so `/bin/sh` and `/unpackerr` are both there, and the
  umask wrapper still works.
- **`Enabled()` is now only the address**, which retires [48]'s "both keys".
  `UN_WEBSERVER_METRICS` still alone registers `/metrics`.

### The exit pin, found on the way

gluetun reconnected on 2026-10-14 and landed on `187.15.91.60`, so `vpn-exit-ip`
and `qbittorrent-bound-to-tunnel` had been red against a stale `.66`. Traffic
stayed on `tun0`. The literal moved in the same commit, per [06]. No tracker
re-authorisation: they object only to many IP changes in a short period, and one
disconnect a month or so is fine.

### Verified

`Up` on v1.0.1, UID 99, `Umask: 2`, `Polling: /downloads @ 1s`. gatus green on
both conditions with the scoped key. A throwaway zip extracted in the watched
folder to `775`/`664` `nobody:users`, source untouched, then removed.
