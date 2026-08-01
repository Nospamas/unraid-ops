# 07 — Decide the repo layout and per-service conventions

Type: grilling
Status: open
Blocked by: 02, 03

## Question

What is the atom of this repo, and what does adding a service look like?

home-ops answers this with an **App** — one directory per workload, a `ks.yaml`
plus an `app/` dir, named by the `&app` anchor. This repo needs its own answer,
in its own vocabulary. Run `/domain-modeling` alongside the grilling and write
the result to `CONTEXT.md`.

**[02](02-choose-reconcile-mechanism.md) adds two things the layout must carry:**

- **Komodo's own resource declarations.** ResourceSync declares Stacks, Servers
  and Procedures as TOML in this repo and diffs them against reality — that is
  why Komodo was chosen. So the repo holds *two* kinds of file per service: the
  compose file and the Komodo Stack TOML that points at it. Decide whether they
  sit together per service or in separate trees.
- **The restart policy is no longer a free choice.** Unraid's autostart list is
  keyed by *container name*, so unraid and compose will race for any container
  unraid still autostarts. The migration turns unraid autostart **off** per
  container and `restart: unless-stopped` in compose takes over — which settles
  the bullet below rather than leaving it open. Note the ordering: autostart off
  *before* compose takes the container.

Settle:

- **Directory shape** — one compose file per service, or one stack grouping the
  media services? The reconcile mechanism from ticket 02 may force this.
- **The unit's name** — "service", "stack", "app" — and what it owns.
- **Shared configuration** — the PUID/PGID/TZ trio, appdata root, and the media
  library paths appear in every service. Where do they live so they are stated
  once? Compose `extends`, a YAML anchor file, or a `.env` at the root.
  [09](09-unify-uid-gid.md) decides what the *values* are; this ticket decides
  where they live. Coordinate with [13](13-local-tooling.md): if mise exports
  these via a `.mise.toml` `[env]` block for local tooling, a root `.env` may be
  redundant.
- **What appdata paths look like** in git: uniformly
  `/mnt/user/appdata/<service>` → `/config`, except plex
  (`/mnt/user/appdata/plexmediaserver`) and calibre, which also binds
  `/mnt/user/Media/books` → `/config/Calibre Library` — note the space in that
  container path. Media root is `/mnt/user/Media`.
- **Eight services, not five** — see the map's Container scope note. The layout
  must also carry plex's `/dev/dri` device passthrough and pinned `VERSION`,
  gluetun's `cap_add: NET_ADMIN`, lazylibrarian's `DOCKER_MODS`, and
  qbittorrent's `network_mode: service:gluetun`. Three of them (plex, gluetun,
  qbittorrent) already have compose definitions in Portainer's appdata that can
  be lifted; the other five exist only as unraid template XML.
- **Restart policy** — the dockerMan-managed five are `restart: no` because
  unraid handles autostart itself; the Portainer three are `unless-stopped`.
  Compose has to state this explicitly for every service, so pick one.
- **Image tags** — everything is on `latest` today and 5–8 months stale. Whether
  the layout pins tags shapes the Renovate question sitting in the map's fog.
- **Where secrets are referenced.** [03](03-secrets-handling.md) has resolved and
  constrains this concretely: encrypted files are **dotenv**, not YAML (the
  consumer is `--env-file`), each Stack's `pre_deploy` decrypts
  `secrets.sops.env` → `secrets.env` and declares `additional_env_files:
  [secrets.env]`. Decide the filenames and whether `.sops.yaml` creation rules
  are one root rule or per-service. Note `secrets.env` must be gitignored, and
  only **five** services carry a secret at all — gluetun, calibre and homepage;
  the *arr containers need none.
- **What "adding a service" is**, written as a short checklist — this is what
  makes the *arr migrations repetitive work rather than fresh decisions.

The answer is the layout, the vocabulary, and the add-a-service checklist.
