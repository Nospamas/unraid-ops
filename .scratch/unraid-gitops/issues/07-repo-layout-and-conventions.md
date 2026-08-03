# 07 — Decide the repo layout and per-service conventions

Type: grilling
Status: closed
Assignee: Nospamas
Resolved: 2026-08-01
Blocked by: 02, 03
Assets: [CONTEXT.md](../../../CONTEXT.md),
[docs/conventions.md](../../../docs/conventions.md),
[docs/adding-a-service.md](../../../docs/adding-a-service.md)

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

**[04](04-reverse-proxy-and-domain.md) adds three more things the layout must
carry:**

- **A shared external `proxy` docker network.** Caddy discovers services by
  label, but it can only reach what shares a network with it. Every fronted
  service joins `proxy` in addition to its own stack network — so the layout
  needs a place to declare that network once and a convention for joining it.
  **[06](06-qbittorrent-vpn-topology.md) has resolved the open half of this**: a
  shared network *does* solve the *arr → qbittorrent problem too, so the two
  needs likely collapse into one network rather than two. Three wrinkles come
  with it, all landing on this ticket:
    - It must be **`external: true`** in every stack that references it, because
      Komodo runs each stack as its own compose project. Something outside the
      stacks has to create it once — a Komodo Procedure, or a declaration that
      one stack owns. Decide which, and where it is written.
    - **gluetun joins it, not qbittorrent.** A container using
      `network_mode: service:gluetun` has no network identity of its own, so it
      cannot join a network and does not resolve by name. The *arr address
      `http://gluetun:30024`.
    - By the same logic, **qbittorrent's `caddy` labels have to sit on the
      gluetun service**. If the add-a-service checklist assumes labels live on
      the container being fronted, this is the exception that breaks it.
- **Routing lives in labels.** A service's hostname is a `caddy` label on its own
  compose file, not central config — so "adding a service" grows a routing step,
  and the add-a-service checklist must say what a standard label set looks like.
- **A built image, not just pulled ones.** Caddy needs a Dockerfile in this repo
  plus a Komodo `Build` resource in TOML. Decide where a Dockerfile lives when a
  service needs one — beside its compose file, or a separate `build/` tree — and
  whether `Build` TOML sits with the `Stack` TOML.

**[05](05-remote-access.md) adds a convention the layout must enforce, and one
more workload:**

- **Default-deny is a layout concern, not a Caddy concern.** Every service
  carries a `caddy.import: internal` label admitting only `192.168.1.0/24` and
  `100.64.0.0/10`; a service meant to face the internet must **declare that
  explicitly**, and the declaration must be conspicuous in review. This belongs
  in the add-a-service checklist as a default, not an option — the whole point is
  that publishing can never be a side effect of adding a service. Decide where
  the `(internal)` Caddyfile snippet itself lives, given `caddy-docker-proxy`
  takes global config from the Caddy container's own labels or a mounted base
  Caddyfile.
- **CoreDNS is a ninth workload** ([17](17-deploy-coredns.md)), and an unusual
  one: it publishes on an **explicit host address** (`100.126.56.26:53`) rather
  than a port on all interfaces. If the layout has a convention for how ports are
  declared, it needs to accommodate that.

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

## Resolution

The answer is three files in the repo proper, not in this ticket:
[CONTEXT.md](../../../CONTEXT.md) (the vocabulary),
[docs/conventions.md](../../../docs/conventions.md) (the layout and its
conventions) and [docs/adding-a-service.md](../../../docs/adding-a-service.md)
(the checklist). What follows is the gist and the reasoning.

**The atom is a Stack: one directory under `stacks/`,** holding its compose file
*and* its Komodo TOML. Komodo's own noun, so repo vocabulary and tool vocabulary
never diverge — and it correctly admits a multi-container unit, which a
"service" directory would not. Adding a service is copying a directory; removing
one is deleting a directory, and the Komodo resource goes with it. Eleven Stacks,
twelve containers.

**Exactly one Stack holds more than one Service.** `download` — gluetun plus
qbittorrent — because [06](06-qbittorrent-vpn-topology.md) established they must
recreate together, and `network_mode: service:` cannot cross compose projects
anyway. A strict one-service-per-directory rule was considered and fails on that
second fact, not on taste.

**The tree is flat: no infra/apps tiers.** Caddy and CoreDNS are workloads like
any other, which matches the map's "no two-tier box" stance. The exception is
`bootstrap/` — Komodo's own three containers, in git so a rebuild starts from a
file rather than from memory, but explicitly never reconciled, because Komodo
cannot deploy the containers it runs inside. This is a *deliberate* file in the
repo that git does not own the reality of; the alternative (leave it out, so
every compose file in the repo is one Komodo deploys) was rejected because the
rebuild story is worth the one exception to explain.

**Shared config is `common.env` at the root**, reaching each Stack via
`additional_env_files = ["../../common.env"]` — the same channel
[03](03-secrets-handling.md) already uses for `secrets.env`, so both land in one
interpolation namespace and there is one mechanism to learn rather than two.
Named `common.env` and not `.env` because Komodo generates its own `.env` in
each run directory, and that collision would be silent. **One thing to verify on
the box** ([11](11-stand-up-komodo.md)): that a relative path escaping the run
directory resolves at all. If it doesn't, the fallback is a symlink per Stack —
not eleven copies of the values. Compose `extends` was the runner-up and lost on
merge-semantics surprise for a gain (inheriting labels and restart policy) the
checklist covers anyway. **`mise` is not an option here at all** — the ticket
wondered whether a `.mise.toml` `[env]` block made a root `.env` redundant; it
does not, because mise runs on the laptop and never on the box.

**One shared network, `shared`, not two.** [06](06-qbittorrent-vpn-topology.md)
left open whether Caddy's discovery network and the *arr→gluetun network
collapse; they do. gluetun has to be on the network either way — it answers
`:30024` for the *arr *and* carries qbittorrent's `caddy` labels — which leaves
a second network separating nothing. Named `shared` rather than `proxy` because
it carries more than proxy traffic.

**Every Stack's `pre_deploy` creates the network idempotently.** It must be
`external: true` everywhere, since Komodo runs each Stack as its own compose
project, so something has to create it — and the two tidier-looking answers each
give up something. One Stack owning it makes Caddy a deploy-order dependency for
the whole box; a hand-run `docker network create` is off-git state that a rebuild
silently omits. Two repeated lines in eleven files buys order-independence,
rebuild-safety and git ownership. It also makes `pre_deploy` uniform: every Stack
has one, the three with secrets just do more.

**Caddy's global config is a real bind-mounted `Caddyfile`**, not labels on the
Caddy container. The `(internal)` snippet from [05](05-remote-access.md) is
multi-line Caddyfile syntax, and it stays that — a reviewer meeting
`caddy.import: internal` on a service has one file to open to learn what it
admits, rather than an ordered set of escaped label keys.

**Default-deny is enforced, not merely conventional.** `scripts/check-exposure.sh`
asserts that every Service carrying a `caddy:` hostname label also carries either
`caddy.import: internal` or an explicit `x-published: true`. 05 made
default-deny standing policy and asked that publishing be conspicuous in review;
a checklist bullet is honour-system, and a forgotten label is silently reachable
from anywhere Caddy is. Now it fails a check instead. `x-published` doubles as
the one grep that answers "what faces the internet" — today, nothing.

**Images are pinned by digest with the version in the same string** —
`sonarr:4.0.19.2995@sha256:e679d9…` — verified as the existing `~/home-ops`
convention. The digest pins; the version tag is what a human reads; Renovate
maintains both, so the readable half cannot drift the way a comment beside it
would. **This substantially decides [12](12-image-update-strategy.md)** — digests
are what Renovate bumps, and Komodo's own auto-update path wants `latest`. 12
survives as a Renovate-configuration ticket, not a two-way choice. **One
exception:** Caddy is built on the box and never touches a registry, so it has no
digest to pin and is referenced by tag alone — the only bare tag allowed, and
because there is no registry, not because pinning was skipped.

**Komodo TOML sits with the compose file it declares** (`stacks/<name>/komodo.toml`),
and a `[[build]]` sits in the same file as its `[[stack]]`, as does a Dockerfile
in the same directory. `komodo/` holds only what is not per-Stack: the
ResourceSync, the Server, the reconcile Procedure. Every `[[stack]]` sets
`project_name` explicitly — **and for the three Portainer stacks it must match
the existing project name, read off the box, or Komodo builds a second copy
beside the running one instead of adopting it.**

**Settled without a fork, for the record:** filenames stay as 03 set them
(`secrets.sops.env` → gitignored `secrets.env`, dotenv not YAML); **one root
`.sops.yaml` creation rule** on `\.sops\.env$`, since there is one key and one
recipient, so per-Stack rules would be ceremony with nothing in them; **four**
Stacks carry a secret, not five — `download`, `calibre`, `caddy` and `homepage`
(this ticket's body said five and then listed three, and predated 04's
Cloudflare token);
`restart: unless-stopped` stated explicitly in every compose file, with unraid
autostart turned **off before** compose takes a container; appdata as
`${APPDATA}/<stack>` → `/config` with plex (`plexmediaserver`) and calibre (the
`Calibre Library` bind, space included) as the two carried-over exceptions;
CoreDNS's explicit host bind `100.126.56.26:53` accommodated as a full
`<host-ip>:<host-port>:<container-port>` publish.

**No new secrets.** The layout adds a repo check and a docs tree; it does not add
a value anyone has to keep.
