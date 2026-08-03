# Map: Unraid GitOps

## Destination

A `git push` to this repo reconciles the unraid box automatically, with sonarr,
radarr, prowlarr, qbittorrent (behind a VPN) and homepage all running from
definitions held here, fronted by a reverse proxy on a real domain and reachable
from outside the house.

## Notes

**Domain**: GitOps for Docker on Unraid — compose-style container definitions in
git, reconciled onto the host. Not Kubernetes; no Flux/Talos vocabulary carries
over.

**Execution override**: this map carries execution, not just decisions. The
destination is a running stack, not a spec.

**Adoption, not greenfield**: the *arr stack and friends already run on the box,
with config and history to preserve. Every migration ticket adopts without data
loss.

**`~/home-ops` is unrelated** — different site, no shared DNS or domain, no
coordination. A reference for *taste* only: the SOPS habit, Renovate, and the
shape of its gethomepage config.

**The repo holds the standing rules, not this map**
([07](issues/07-repo-layout-and-conventions.md),
[28](issues/28-navigable-standing-docs.md)): [CLAUDE.md](../../CLAUDE.md) is
auto-loaded and points at [CONTEXT.md](../../CONTEXT.md) (vocabulary),
[docs/conventions.md](../../docs/conventions.md) (the rules, indexed — read the
section, not the file) and
[docs/adding-a-service.md](../../docs/adding-a-service.md) (the routine, read
before adding or migrating a service). **Do not add a fifth doc, and do not
restate those rules here.** Two divisions to respect: rationale lives in the
*ticket*, the doc holds the rule plus a `[NN]` citation; and `conventions.md`
states the rule where `adding-a-service.md` holds the template. If the checklist
turns out to need a *decision* rather than a keystroke, amend the doc and say so
on the ticket.

### Box access

SSH works — `root@tower` over tailscale, key-based, key persisted at
`/boot/config/ssh/root.pubkeys`. Box tickets need no paste-back checklist.

**This tightens caution rather than relaxing it.** The only other remote path is
the Unraid Web UI on **port 8008 over tailscale**
([15](issues/15-move-unraid-gui-ports.md)); there is no out-of-band console, and
the human has said a lockout is a multi-day outage.

- State the rollback before any change touching port 80/443, docker networking,
  or tailscale.
- **[16](issues/16-deploy-caddy.md) is the only live lockout risk** — it puts a
  proxy on the ports a browser reaches the box by. It does not run without a
  tested way back in.
- **Portainer is a second lifeline** (:9000) until SSH has proven itself; its
  retirement ([25](issues/25-retire-portainer.md)) waits on that, not just on
  adoption.

### Komodo is live ([11](issues/11-stand-up-komodo.md))

v2.3.1 on `http://192.168.1.195:9120`, Server `tower` connected. **Prefer Core's
HTTP API to its UI** for anything an agent drives — the UI keeps Deploy one
mis-click away. Credentials are `admin` plus the generated password in
[bootstrap/secrets.sops.env](../../bootstrap/secrets.sops.env), which **is the
source of truth and must stay it**: `KOMODO_INIT_ADMIN_*` is create-if-absent, so
changing the password in the UI strands the committed value. Five wrong
passwords lock the account.

Two facts every box ticket needs: a `files_on_host` path must sit under
`/mnt/user/appdata/komodo`, and **any image running as a non-root uid needs its
bind-mount target pre-created and chowned** — Docker makes missing targets
`root:root`.

**No agent POSTs to Core's API ad hoc.** New operations go in
[scripts/komodo.sh](../../scripts/komodo.sh) behind a recipe; drive the loop with
`just reconcile`.

### Standing rulings

**Surface the hand-offs.** Most tickets end owing the human actions only they can
perform. **Put them in their own block at the very end of the session summary —
never as a closing prose paragraph.** One line each, starting with the verb,
saying what stays broken until it is done. 13's Renovate config sat inert waiting
on one click.

**Container scope**: git owns all eight adopted workloads (sonarr, radarr,
prowlarr, qbittorrent, gluetun, plex, calibre, lazylibrarian) plus four built new
(homepage, Caddy, CoreDNS, dockerproxy). No two-tier box. Portainer is retired
once its stacks are adopted; Komodo's own four containers are the only
non-workload tenants. **Homepage and dockerproxy are live**; the eight adopted
are [21](issues/21-migrate-arr-stacks.md)–[24](issues/24-migrate-download-stack.md).

**Secret severity**: the NordVPN *client* key and the calibre GUI password are
ruled **low-value** — both were already plaintext on the box, and neither grants
access to the box, LAN or tailnet. **Do not re-raise rotation as a blocker or a
finding**; rotation has not happened and is not scheduled. The one live carve-out
is *future* exposure, not the current leak: auth in front of calibre. That is
**fog**, not a ticket — see below.

**Skills to consult**: `/grilling` and `/domain-modeling` for decision tickets,
`/research` for AFK reading, `/prototype` where a rough artifact settles an
argument faster than discussion.

**Settled while charting**: a general unraid GitOps repo, not a homepage-only
one; git owns *container definitions* while each service's own settings stay in
its appdata (homepage excepted); LAN-only IP:port was ruled out; tracker is local
markdown.

## Decisions so far

<!-- one line per resolved ticket — the ticket holds the detail -->

- [01 — Inventory the containers already running on the box](issues/01-inventory-running-containers.md)
  — the box as found, in [assets/01-inventory.md](assets/01-inventory.md): no
  compose on the host, already two-tier, gluetun sidecar already in place,
  PUID/PGID diverging three ways, and no homepage at all.
- [02 — Choose the reconcile mechanism](issues/02-choose-reconcile-mechanism.md)
  — **Komodo**, on the box, beating Portainer because ResourceSync puts Komodo's
  own config in git. Reconcile is **poll, not webhook**.
- [03 — Decide how secrets live in the repo](issues/03-secrets-handling.md)
  — **SOPS + age**, decrypted on the box by a `pre_deploy` hook. Fresh key at
  `/mnt/user/appdata/komodo/age.key`, backed up in KeePassXC; rebuild is clone +
  restore one key.
- [04 — Choose the reverse proxy and the domain](issues/04-reverse-proxy-and-domain.md)
  — **Caddy** (`caddy-docker-proxy`) on **`rbrb.in`**, DNS on Cloudflare, certs
  by DNS-01 wildcard. Traefik was reopened mid-grill and declined on purpose.
- [05 — Decide the remote access approach](issues/05-remote-access.md)
  — **split-horizon, built now**: CoreDNS bound to the tailnet IP, with Tailscale
  Split DNS pointing `rbrb.in` at it. **Nothing is published**, and everything is
  built default-deny to LAN + tailnet as if it will be.
- [06 — Decide the qbittorrent VPN topology](issues/06-qbittorrent-vpn-topology.md)
  — **gluetun sidecar adopted unchanged**; only torrent traffic is tunnelled,
  NordVPN stays, qbittorrent is knowingly leech-only. **New hazard**: recreating
  gluetun orphans qbittorrent in a dead namespace, silently.
- [07 — Decide the repo layout and per-service conventions](issues/07-repo-layout-and-conventions.md)
  — **the atom is a Stack**: one directory holding both its compose file and its
  Komodo TOML. Flat tree, one `shared` network, `common.env` at the root, and
  default-deny enforced by a script rather than a checklist.
- [08 — Deploy homepage from the repo](issues/08-deploy-homepage.md)
  — **the loop is real: a push changed the box in 8m34s, unattended.** The
  Procedure is two stages because a ResourceSync applies nothing by itself, and
  its deploy pattern is an explicit list of Stack names, **never `*`**.
- [09 — Unify PUID/PGID/UMASK](issues/09-unify-uid-gid.md)
  — **99:100 everywhere, no exceptions**, `UMASK=002`. The media binds **do not
  move**: single-mount was decided then reversed on evidence, so hardlinks are out
  of scope. Spawned [20](issues/20-chown-to-99-100.md).
- [10 — Publish the repo to a remote the box can reach](issues/10-publish-repo-to-remote.md)
  — **public GitHub, cloned anonymously, no credential**, which dissolves the
  bootstrap-secret question entirely. History was published as-is after a sweep
  found no key material. **Do not re-raise visibility.**
- [11 — Stand Komodo up on the box](issues/11-stand-up-komodo.md)
  — **v2.3.1 live and reconciling nothing, as intended.** Four containers, not
  three — the database is FerretDB-on-Postgres. Adoption by `project_name` works,
  and `git_account` empty clones the public repo.
- [12 — Decide the image update strategy](issues/12-image-update-strategy.md)
  — **Renovate, and only Renovate**, with four human-merge carve-outs.
  **Nothing is built at all**: a maintained upstream image replaced 04's planned
  Caddy build, deleting 07's bare-tag exception.
- [13 — Decide the local tooling and task runner](issues/13-local-tooling.md)
  — **`just`, not go-task**, with tools pinned in `.mise.toml` and `just lint` as
  the gate. **Biggest find: 03's age keypair had never been generated**, silently
  blocking three tickets.
- [14 — Set up the rbrb.in zone and mint the DNS token](issues/14-cloudflare-zone-and-token.md)
  — **the zone is live and the sixth secret exists.** The ticket's own
  instructions were wrong twice: `Zone / Zone / Read` is required alongside
  `Zone / DNS / Edit`, and the zone was not blank — `webmail.rbrb.in` is a
  reserved hostname Caddy can never own.
- [15 — Move the Unraid Web GUI off ports 80/443](issues/15-move-unraid-gui-ports.md)
  — **the GUI is on 8008/8443 and a container has been shown to take 80 and 443**,
  so 16's blocker is proven gone rather than inferred. Landed as `just host-ports`
  against a snapshot of `ident.cfg`; **only the ports are owned**, and the rest
  went to [26](issues/26-host-state-scope.md).
- [27 — Make every mutating `just` recipe dry-run by default](issues/27-recipe-safety-convention.md)
  — **the rule is provenance, not blast radius**: `--apply` guards a recipe that
  changes the box in a way the reconcile loop would not, so `reconcile` stays
  knowingly **ungated**.
- [28 — Make the repo's standing docs navigable, and auto-loaded](issues/28-navigable-standing-docs.md)
  — **`repo-layout.md` is now [docs/conventions.md](../../docs/conventions.md)**,
  indexed and cut 434 → 280 lines, with [CLAUDE.md](../../CLAUDE.md) finally
  giving the repo something auto-loaded. The reusable part is the division:
  rationale lives in the ticket, the doc holds the rule — later applied to this
  map too, 614 → 217 lines.

## Not yet specified

- **Reconciling on push rather than on a timer.** Komodo supports git webhooks
  and Core already generates the secret, but a webhook needs GitHub to reach Core
  and nothing is published. Sharp once [16](issues/16-deploy-caddy.md) lands and
  something decides whether Komodo is worth publishing — a *scope* question, not
  just plumbing. Until then 15 minutes is the answer, not a defect.
- **Appdata backup and box rebuild.** With definitions in git, appdata is the
  remaining single point of failure — 24G, dominated by plex — and Komodo's own
  database is new off-git state holding the resource records.
- **Authentication in front of the services.** 04 and 05 both declined it,
  correctly: nothing is published, so there is nothing to defend. 05 built the
  *gate*, deliberately not the defence. Sharp the moment a service is actually
  published, or the LAN stops being trusted (guest wifi, IoT). **No ticket should
  be opened for it before then.**
- **Whether the LAN half of split-horizon ever needs its own resolver.** 05 leans
  on Cloudflare's public record *being* the LAN view, which works precisely
  because nothing is published. A forwarded port would break that coupling.
- **Monitoring and alerting.** The sharpest thing here: `failure_alert` is on with
  **no alerter configured to receive it**, so a failing reconcile is currently
  silent, and the box already changes on a timer with nobody watching.
  [12](issues/12-image-update-strategy.md)'s human-merge carve-outs *are* the
  stand-in for monitoring and should be revisited once something is watching.

## Out of scope

- **Decommissioning or migrating `~/home-ops`.** Different site, stays as it is.
- **Unraid array, share and disk configuration.** This map governs containers and
  their config, not the storage layer underneath.
- **Hardlinked imports, and the single `/media` mount that would enable them**
  ([09](issues/09-unify-uid-gid.md)). Out on capability, not sharpness: the
  destination does not need them, and on six XFS disks under shfs they cannot
  reliably work. **Not** a tidy-up to do in passing, which is why
  [docs/conventions.md](../../docs/conventions.md) says so at the binds.
