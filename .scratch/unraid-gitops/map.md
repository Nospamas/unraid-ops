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

**`~/home-ops` is unrelated** — different site, different domain, no
coordination. A reference for *taste* only: the SOPS habit, Renovate, and the
shape of its gethomepage config.

### Two networks, bridged only by tailscale

This matters for every DNS and reachability decision, and reading "LAN" as one
thing will get it wrong:

| | rb's network | the home network |
|---|---|---|
| holds | `tower`, `192.168.1.0/24` | the human, this clone, `~/home-ops` |
| addressing | `192.168.1.0/24` | **`192.168.0.0/16`**, local domain `xgy.im`, IPv6 ULA present |
| resolver | `192.168.1.254`, rb's router — **none of ours, and it strips `192.168/16` answers** ([32](issues/32-lan-resolver.md)) | **pihole** at `192.168.2.254`, and we can change it |
| means "LAN" in tickets | yes, and in the `(internal)` guard | no |

**Separate physical networks, joined only over the internet by tailscale.**
Their address space nonetheless overlaps: the home network's `/16` covers rb's
`/24`, so a home device sends `192.168.1.195` **out its own LAN interface**
(`ip route get` confirms) and gets silence. The public record is not merely
unroutable there — it is absorbed locally. Two consequences: it independently
confirms [05](issues/05-remote-access.md)'s shadowed-route grounds for declining
a subnet router, and the `(internal)` guard's `192.168.1.0/24` entry would 403 a
home device if one ever arrived by a non-tailscale path.

**The tailnet is four nodes** — `tower`, `ubuntu-dev`, `earth`, `uranus`. No
phone. MagicDNS is on tailnet-wide; the per-device switch that matters is
`--accept-dns`, **off on tower and it must stay off**, on for `ubuntu-dev` and
`uranus`, never audited on `earth`
([18](issues/18-tailnet-split-dns.md)).

So [04](issues/04-reverse-proxy-and-domain.md)'s public
`*.rbrb.in` → `192.168.1.195` is the correct answer **only on rb's network**.
Everywhere else that record is unroutable, which
[17](issues/17-deploy-coredns.md) and [18](issues/18-tailnet-split-dns.md) — both
now closed — fix. **Split-horizon is delivered on the tailnet, and has never
worked on rb's LAN.**

The "conveniently, no resolver to configure" claim this map carried until
[29](issues/29-alerting-on-failed-reconcile.md) was **false, and untested**.
rb's router strips answers in `192.168.0.0/16` and returns `NOERROR` with no
answer, so nothing using it resolves any `rbrb.in` name. It is not rebind
protection in the usual sense — `10/8`, `172.16/12` and `127/8` all pass; only
its own LAN range is filtered. Every verification this map ever ran came from
the tailnet, where `--accept-dns` routes around the router entirely. **This is
[32](issues/32-lan-resolver.md).**

**Pihole is a real option, reopened, and ruled against on the record.** It could
answer `rbrb.in` → `100.126.56.26` for the whole home network in one edit, and
the human stopped [17](issues/17-deploy-coredns.md) mid-session to ask whether
CoreDNS was needed at all. Laid out, the two are **identical everywhere except
one row**: a device on neither network has no pihole and no route to
`192.168.1.195`. **Roaming is in scope** — that ruling is the entire
justification for CoreDNS, and both options put one record in state git does not
own, so that is a wash rather than a tiebreaker. **Do not re-raise this without
redrawing the destination.**

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
- **No live lockout risk remains.** [16](issues/16-deploy-caddy.md) was the last
  one and is closed: Caddy holds 80/443, the GUI is on 8008, and the two never
  meet. `ident.cfg.bak-15` is gone, and restoring it now would put unraid's nginx
  into a fight with Caddy rather than rescuing anything.
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

**And `pre_deploy` is only able to do that because
[29](issues/29-alerting-on-failed-reconcile.md) widened Periphery's binds.** It
runs *inside* Periphery, which saw only `/mnt/user/appdata/komodo`, so a `mkdir`
and `chown` on any other path silently built a correct directory nobody could
see while docker made the real one `root:root`. Every earlier `pre_deploy` only
ever touched the docker socket or the run directory, so nothing had exercised
it. **A path outside Periphery's binds is still a no-op that reports success.**

**No agent POSTs to Core's API ad hoc.** New operations go in
[scripts/komodo.sh](../../scripts/komodo.sh) behind a recipe; drive the loop with
`just reconcile`.

**A Procedure cannot update itself** ([16](issues/16-deploy-caddy.md)). Komodo
refuses to update a busy resource, and `reconcile` is the Procedure running the
sync that would update it — so an edit to `komodo/procedures.toml` fails the
whole run with a message that discards its own cause. `just reconcile` syncs
bare first to cover it; **the cron cannot**, and fails every 15 minutes until
someone runs the recipe.

### Standing rulings

**Surface the hand-offs.** Most tickets end owing the human actions only they can
perform. **Put them in their own block at the very end of the session summary —
never as a closing prose paragraph.** One line each, starting with the verb,
saying what stays broken until it is done. 13's Renovate config sat inert waiting
on one click.

**Container scope is closed.** Git owns all eight adopted workloads (sonarr,
radarr, prowlarr, qbittorrent, gluetun, plex, calibre, lazylibrarian) plus six
built new (homepage, Caddy, CoreDNS, dockerproxy, ntfy, gatus). No two-tier box. **Nothing is
left to migrate** — the only containers git does not own are Portainer, which
[25](issues/25-retire-portainer.md) removes, and Komodo's own four.
**Adoption splits by manager, not by service**
([21](issues/21-migrate-arr-stacks.md)): unraid's dockerMan containers carry no
compose labels and were *removed* by `just adopt`, all five of them. Portainer's
are the other case — adopted in place by `project_name`, and
[23](issues/23-migrate-plex.md) settled what that does: it **recreates**, under
a new container name, keeping the network alias. Which is the safe direction for
24, since 06's hazard is recreating gluetun *alone* — and 24 has now run it that
way and held. Caddy is the one Stack on **host networking**, and it is not a
preference — [16](issues/16-deploy-caddy.md).

**Secret severity**: the NordVPN *client* key and the calibre GUI password are
ruled **low-value** — both were already plaintext on the box, and neither grants
access to the box, LAN or tailnet. **Do not re-raise rotation as a blocker or a
finding**; rotation has not happened and is not scheduled. The one live carve-out
is *future* exposure, not the current leak: auth in front of calibre. That is
**fog**, not a ticket — see below.

**Permissions are settled and enforced** ([19](issues/19-secret-hygiene-on-the-box.md),
[20](issues/20-chown-to-99-100.md)): 99:100, **`UMASK=002`**, 775/664, and no 777
anywhere. `UMASK=022` is a bug, not a default — it is what forced the `chmod -R
777` this map inherited. All three of `nobody`(99), `share`(1000) and
`rseaforthb`(1001) have primary gid **100**, so group-write is the mechanism.
**Samba is not involved** — its masks are 0777 and strip nothing. `just
permissions` re-normalises; the rule is in
[docs/conventions.md](../../docs/conventions.md).

**A green reconcile is not a running service.** Twice now
([16](issues/16-deploy-caddy.md), [21](issues/21-migrate-arr-stacks.md)) a
deploy has left a workload dead while Komodo reported success — a stale bind,
then containers `Up` with no networks at all. `DeployStackIfChanged` compares
the config hash, so a correct hash over a broken container is silence, and a
restart does not repair it. `just redeploy <stack>` destroys and rebuilds one
named Stack, which is the only cure. **Check the workload, never the update
log.** [29](issues/29-alerting-on-failed-reconcile.md) closed this: gatus probes
every fronted service end to end, because Komodo cannot see it — all three
sightings were containers that stayed `Up`, and `StackStateChange` fires on a
*mix* of container states.

**"Nothing is published" is no longer true, and the grep that says so is blind.**
[23](issues/23-migrate-plex.md) verified plex answering on
`75.155.182.130:32400` from outside both networks, through a router forward that
predates this repo. `x-published` and `check-exposure.sh` reason about the
**Caddy** path only, so a host port plus a router is invisible to both.
[31](issues/31-plex-own-internet-exposure.md) rules on it; until then, say "the
repo publishes nothing", which is the claim that is actually true. The forward is
**plex's alone**: [24](issues/24-migrate-download-stack.md) probed 6881 and 30024
from outside and both time out, so 32400 is the one hole in rb's router.

**Add one Stack to the deploy pattern at a time** when adopting. All four at
once is what caused the above: the three not yet freed deployed into ports
unraid still held.

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
- [16 — Stand the Caddy proxy up](issues/16-deploy-caddy.md)
  — **`https://home.rbrb.in` serves a trusted `*.rbrb.in` wildcard**, staging
  first and issued on the first attempt. Three quiet failures found: Tailscale's
  masquerade makes 05's guard 403 the tailnet behind published ports, so **Caddy
  is host-networked**; a single-file bind goes ESTALE on the next git pull and
  takes Caddy down while the reconcile reports success; and a Procedure cannot
  update itself. Spawned [29](issues/29-alerting-on-failed-reconcile.md).
- [28 — Make the repo's standing docs navigable, and auto-loaded](issues/28-navigable-standing-docs.md)
  — **`repo-layout.md` is now [docs/conventions.md](../../docs/conventions.md)**,
  indexed and cut 434 → 280 lines, with [CLAUDE.md](../../CLAUDE.md) finally
  giving the repo something auto-loaded. The reusable part is the division:
  rationale lives in the ticket, the doc holds the rule — later applied to this
  map too, 614 → 217 lines.

- [17 — Deploy CoreDNS for the tailnet view](issues/17-deploy-coredns.md)
  — **CoreDNS is live on `100.126.56.26:53` and every `rbrb.in` name answers
  tower's tailnet address**, verified from off both networks. The question was
  reopened before it was built and **roaming was ruled in scope**, which is the
  whole justification for the Stack. `.` **REFUSEs** rather than forwarding:
  Split DNS is restricted to a domain, so each client keeps its own resolver for
  everything else. No `:53` collision existed. Corrected [18](issues/18-tailnet-split-dns.md),
  whose MagicDNS prerequisite was already done.
- [19 — Settle secret hygiene on the box](issues/19-secret-hygiene-on-the-box.md)
  — **Periphery's umask is 0022, so every decrypted `secrets.env` was 0644**;
  `(umask 077; sops -d …)` fixes it and `just lint` enforces it. The boundary is
  not directory perms — appdata is exported over **neither SMB nor NFS** and only
  Periphery binds the tree. **`/boot` holds no WireGuard key** (01 was wrong);
  the *calibre password* is the asset on `/boot`, inverted from what 01 and 03
  assumed. Portainer's **database** holds the key too, which 25 must count.
- [20 — Chown the tree to 99:100 and normalise permissions](issues/20-chown-to-99-100.md)
  — **rolled into 19 and executed: the `chmod -R 777` is gone**, and it was a
  stopgap for `UMASK=022`, which creates 755 dirs rb cannot move media out of.
  All three divergent services are 99:100 with their Portainer stacks redeployed
  in the same window. **`/dev/dri` was never a risk** — `renderD128` is 777, so
  23's transcode check is settled. **No compose binary exists on the box.**
- [18 — Point Tailscale Split DNS at CoreDNS](issues/18-tailnet-split-dns.md)
  — **one restricted-nameserver row delivers split-horizon**, and 05's answer is
  complete. The pihole risk is dead *structurally*: Windows routes per-domain via
  **NRPT rules with no `.` catch-all**, so it cannot go all-or-nothing. Two traps
  recorded — the console has no "Split DNS" section, and the mis-click that makes
  CoreDNS global (killing all DNS everywhere) is the same dialog; and on Windows
  `nslookup` bypasses the NRPT and reports a false failure.

- [21 — Migrate sonarr, radarr, prowlarr and lazylibrarian](issues/21-migrate-arr-stacks.md)
  — **all four are Stacks, on `shared`, behind Caddy, with their libraries
  intact.** The framing was wrong: these came from unraid's Docker tab, carry
  **no compose labels**, and so cannot be adopted at all — `just adopt` removes
  them and the Stack rebinds the same appdata. Adding all four to the deploy
  pattern at once left three `Up` with no networks and no ports, which
  **`Execution ok` reported as success**; spawned `just redeploy` and
  [30](issues/30-arr-urls-on-shared.md).

- [22 — Migrate calibre](issues/22-migrate-calibre.md)
  — **calibre is a Stack and `https://calibre.rbrb.in` is its only door.** All
  three host ports went: 8081's content server had **nothing listening behind
  it**, 8181 is the same GUI over a self-signed cert, and nothing but a browser
  addresses calibre — lazylibrarian uses `calibredb` on the shared mount, not
  HTTP. Diffing the container's env against the *image's* showed the unraid
  template had set only the five standard vars and the login pair; the other
  eighteen were cargo. **Unraid's Docker tab now holds only `PortainerCE`.**

- [23 — Migrate plex](issues/23-migrate-plex.md)
  — **plex is a Stack, on `shared`, five libraries intact, and adoption in place
  recreates rather than no-ops** — under a new container name, keeping the
  network alias. `VERSION` was the find: pinned to a Plex Pass build for B580
  support, it re-downloaded and installed 84MB over the image at **every start**,
  so the digest pinned nothing. `VERSION: docker` and the public release fix it.
  `/mnt/transcode` had been mounted at a path plex never asked for. Spawned
  [31](issues/31-plex-own-internet-exposure.md), which is the one that matters:
  plex answers from the public internet, and the repo's exposure grep cannot see
  it.

- [24 — Migrate the download Stack (gluetun + qbittorrent)](issues/24-migrate-download-stack.md)
  — **the pair is one Stack on `shared`, and the tunnel held across the
  recreate**: qbittorrent's own egress is the VPN's, its namespace points at the
  live gluetun, and 23 torrents are untouched. `latest` pinned nothing on either
  image, but only qbittorrent had a lift available — gluetun's was an untagged
  master build, so it landed on **v3.41.3** deliberately. Four env vars gluetun
  never read were **dropped rather than carried**, reversing this ticket's own
  instruction, and the rule went to
  [adding-a-service.md](../../docs/adding-a-service.md). 6881 is gone: rb's
  router forwards it no more than it forwards 30024.

- [26 — Decide how much of the box's host state git owns](issues/26-host-state-scope.md)
  — **ports only, and the ticket was asking the wrong question.** Every flash
  candidate was tested on the box and every one failed; the one that passes —
  `192.168.1.195` — is a **DHCP lease in rb's router**, so git cannot have it.
  The fix is to stop addressing the box by IP, which is now the **Addressing**
  rule in [docs/conventions.md](../../docs/conventions.md), enforced by
  `x-host-port`. Three host ports qualify and no more, the third being new: *the
  tooling that repairs Caddy must not sit behind Caddy* — so `komodo.rbrb.in`
  and `unraid.rbrb.in` are served **and** keep `:9120` and `:8008`.

- [29 — Give `failure_alert` somewhere to go](issues/29-alerting-on-failed-reconcile.md)
  — **two Stacks, one Alerter, and no seventh secret**: a self-hosted `ntfy` the
  phone reaches over the tailnet, and a `gatus` that probes all ten hostnames
  plus a DNS query end to end. The rule it produced is **the alert path must not
  traverse the thing it reports on** — so ntfy takes no `caddy` label and gatus
  is host-networked, since a probe from `shared` is 403'd by 05's guard before
  `reverse_proxy` runs. Komodo's premise was wrong (22 alert variants, not one)
  and it changed nothing: all three sightings stayed `Up`. **Six of ten services
  do not answer 200** — measured, not assumed. Released 12's `download` and
  `coredns` carve-outs. **Live: 11/11 probes pass and gatus has delivered a real
  alert.** Three silent failures on first deploy — `pre_deploy` writing to
  Periphery's own filesystem, the box unable to resolve its own hostnames, and
  gatus following redirects into a 200. **Box-down is not closed** and now
  depends on home-ops.

## Not yet specified

- **Reconciling on push rather than on a timer.** Komodo supports git webhooks
  and Core already generates the secret, but a webhook needs GitHub to reach Core
  and nothing is published. [16](issues/16-deploy-caddy.md) has landed, so the
  proxy that would front it now exists; what is still unsettled is the *scope*
  question — whether Komodo is the first thing this map publishes. Until then 15
  minutes is the answer, not a defect.
- **Appdata backup and box rebuild.** With definitions in git, appdata is the
  remaining single point of failure — 24G, dominated by plex — and Komodo's own
  database is new off-git state holding the resource records. [24](issues/24-migrate-download-stack.md)
  found the NordVPN key in that database in plaintext, left by 11's adoption, so
  a backup of it is a backup of a secret.
- **Authentication in front of the services.** 04 and 05 both declined it,
  correctly: the repo publishes nothing, so there is nothing to defend. 05 built
  the *gate*, deliberately not the defence — and [16](issues/16-deploy-caddy.md)
  has now proved the gate works in both directions. Sharp the moment a service is
  actually published, or the LAN stops being trusted (guest wifi, IoT). **No
  ticket should be opened for it before then.** Plex is not the exception it
  looks like: it is reachable from the internet, but by its own port forward and
  behind its own account auth, which is
  [31](issues/31-plex-own-internet-exposure.md)'s question, not this one's.
  qbittorrent is the sharpest case: [24](issues/24-migrate-download-stack.md)
  left its API unauthenticated to everything on `shared` and, through Caddy, to
  everything the `(internal)` guard admits. Deliberate, and only sound while that
  guard is.
- **What a moved DHCP lease costs.** [26](issues/26-host-state-scope.md) found
  that `192.168.1.195` is a lease, not configuration, and after 30 the Cloudflare
  record is the last thing betting on it. This shrank when
  [29](issues/29-alerting-on-failed-reconcile.md) showed rb's router never served
  that record anyway: a moved lease breaks nothing that currently works, and the
  tailnet resolves via CoreDNS regardless. A reservation on rb's router is still
  the mitigation, and still a hand-off rather than a ticket — but see
  [32](issues/32-lan-resolver.md), which may make the lease matter again.
- **Home-network devices that are not on the tailnet.** They have no route to
  tower at all, and no DNS answer can give them one — it would take a subnet
  router, which [05](issues/05-remote-access.md) declined on shadowed-route
  grounds. Sharp only if something on that network that cannot run tailscale
  (a TV, a printer, a guest) actually needs a service.
- **Knowing the box itself is gone.** [29](issues/29-alerting-on-failed-reconcile.md)
  built alerting and deliberately did not close this: ntfy and gatus both die
  with tower, so silence stays indistinguishable from health — and self-hosting
  made it *worse* than a third party, since the notification server is now part
  of the outage. The shape is settled, not fogged: **each site runs its own ntfy,
  alerts to its own, and probes the other**, which needs no cross-site
  credential. tower's half is built and tailnet-reachable by construction. What
  is genuinely open is **home-ops**, which has no tailscale in the cluster at
  all — specified in
  [assets/29-home-ops-alerting-brief.md](assets/29-home-ops-alerting-brief.md)
  and worked in that repo, not this one. This map's own remaining piece is the
  mirror-image probes in `stacks/gatus/conf/config.yaml`, which cannot be written
  until home-ops has addresses to probe. **Not a ticket until then.**

*(Monitoring graduated to [29](issues/29-alerting-on-failed-reconcile.md), the
*arr host ports to [30](issues/30-arr-urls-on-shared.md), and the LAN resolver
question to [32](issues/32-lan-resolver.md).)*

## Out of scope

- **Decommissioning or migrating `~/home-ops`.** Different site, stays as it is.
- **Unraid array, share and disk configuration.** This map governs containers and
  their config, not the storage layer underneath.
- **The box's host state beyond the GUI's ports**
  ([26](issues/26-host-state-scope.md)). `network.cfg`, `docker.cfg`, `plugins/`,
  the licence and the password files were each tested against "would losing this
  break the stack or the rebuild" and each failed. `bootstrap/host/ident.cfg`
  stays a snapshot of which only Management Access is ever applied. Ruled out on
  evidence, not on sharpness — do not reopen without a candidate that passes
  that test.
- **Hardlinked imports, and the single `/media` mount that would enable them**
  ([09](issues/09-unify-uid-gid.md)). Out on capability, not sharpness: the
  destination does not need them, and on six XFS disks under shfs they cannot
  reliably work. **Not** a tidy-up to do in passing, which is why
  [docs/conventions.md](../../docs/conventions.md) says so at the binds.
