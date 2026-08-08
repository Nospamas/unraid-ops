---
id: "51"
title: Track secrets.sops.env in the three Stacks that still don't
type: grilling
status: open
description: >
  caddy, calibre and download hold secrets that Komodo does not diff, so
  editing one changes nothing and says nothing — the failure 50 found on
  homepage. Not a cleanup: tracking download's secret means a secret edit
  recreates the gluetun/qbittorrent pair unattended.
touches: [stacks/caddy/komodo.toml, stacks/calibre/komodo.toml, stacks/download/komodo.toml]
---

# 51 — Track secrets.sops.env in the three Stacks that still don't

Blocked by: —

## Question

[50](50-homepage-secrets-and-verify.md) found that `secrets.sops.env` is not a
tracked file by default, so a commit editing only a secret diffs to nothing: no
deploy runs, `pre_deploy` never re-decrypts, and the container keeps the
environment it was created with. Green reconcile, correct repo, broken service.
Fixed on homepage by listing it as `redeploy`, and written up in
[conventions.md](../../../docs/conventions.md).

Three Stacks still have it untracked. `calibre` and `download` have **no
`config_files` key at all**.

| Stack | what a secret edit would trigger, once tracked |
|---|---|
| caddy | recreate — the reverse proxy for every fronted service |
| calibre | recreate — one container, contained |
| download | **recreate the gluetun/qbittorrent pair** |

### Why this is a decision and not a chore

`requires = "redeploy"` is correct on its merits — `env_file` is read at
container creation, so nothing less picks a secret up. But it converts a `git
push` into an unattended recreate of whatever the Stack is, and two of these are
the Stacks this repo is most careful about.

**download is the sharp one.** CLAUDE.md already forbids a wildcard in
`BatchDeployStackIfChanged` precisely because it "recreates plex and the
gluetun/qbittorrent pair unattended" — and tracking the secret makes a secret
edit do exactly that, by a different route. The tunnel comes back on a new
NordVPN endpoint and qbittorrent's namespace goes with it.

**caddy is the one that could lock the box out.** Its secret feeds the
Cloudflare DNS-01 token; a recreate that fails leaves nothing serving `:443`.
State the rollback before choosing [15, 16].

So the choice per Stack is roughly: track it and accept the recreate; track it as
`restart` and accept that it does not actually work for `env_file`; or leave it
untracked and rely on `just redeploy <stack> --apply` being remembered — which is
the status quo that just failed on homepage.

### Worth asking

Whether the honest fix is instead a **check** rather than a per-Stack setting:
something that compares what git holds against what the running container has, so
the class of failure in [50] is caught rather than designed around. That would
also have caught 38's missing keys.
