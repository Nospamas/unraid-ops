# Map: Unraid GitOps

## Destination

A `git push` to this repo reconciles the unraid box automatically, with sonarr,
radarr, prowlarr, qbittorrent (behind a VPN) and homepage all running from
definitions held here, fronted by a reverse proxy on a real domain and reachable
from outside the house.

## Notes

**Domain**: GitOps for Docker on Unraid — compose-style container definitions in
git, reconciled onto the host. Not Kubernetes; none of the Flux/Talos vocabulary
carries over.

**Execution override**: this map carries execution, not just decisions. Tickets
may build, deploy and migrate real services — the destination is a running
stack, not a spec.

**Adoption, not greenfield**: the *arr stack and friends already run on the box,
added by hand through unraid's Docker tab, with config and history to preserve.
Every migration ticket must adopt without data loss.

**Relationship to `~/home-ops`**: none. Different location, different household
site — no shared DNS, no shared domain, no cross-links, no coordination. It is a
reference for *taste* only: the SOPS habit, Renovate for image tags, and the
shape of the existing gethomepage config at
`kubernetes/apps/self-hosted/homepage/app/config/`.

**Box access**: the unraid box is reached through its Web UI over tailscale, and
the human drives it. No SSH, no agent access to the host. Any ticket needing
something from the box hands over a precise checklist — commands to run, output
to paste back — and works from what comes back. This makes otherwise-AFK tickets
HITL wherever they touch the box. Direct access can be granted later if the
hand-off proves too slow; until then, assume it is not there.

**Container scope**: git owns *all eight* workload containers, not just the five
the destination names — sonarr, radarr, prowlarr, qbittorrent, gluetun, plex,
calibre, lazylibrarian, plus a homepage that does not exist yet. No two-tier box
where some containers are git-owned and some stay on unraid's Docker tab.
Portainer is excluded: it is currently the deploying tool, not a workload, and
whether it survives at all falls out of
[02 — Choose the reconcile mechanism](issues/02-choose-reconcile-mechanism.md).

**Skills to consult**: `/grilling` and `/domain-modeling` for the decision
tickets, `/research` for the AFK reading tickets, `/prototype` where a rough
concrete artifact would settle an argument faster than discussion.

### Settled while charting

- **Repo scope**: a general unraid GitOps repo, not a homepage-only one.
  Homepage is the proving case, but the conventions must generalise.
- **Reconcile scope**: git owns *container definitions* — image, tag, ports,
  volumes, env. A push recreates the container. Each service's own internal
  settings (sonarr's indexers, quality profiles, root folders) stay in its
  appdata database and are edited in its UI. Homepage is the exception: its
  config is plain YAML files, so git owns it fully.
- **Access**: reverse proxy on a real domain, qbittorrent behind a VPN, and
  remote access from outside the house. LAN-only IP:port was ruled out.
- **Tracker**: local markdown for now. The GitHub remote comes later, once
  enough investigation has landed to be worth pushing.

## Decisions so far

<!-- one line per resolved ticket -->

- [01 — Inventory the containers already running on the box](issues/01-inventory-running-containers.md)
  — the box as found, in [assets/01-inventory.md](assets/01-inventory.md).
  Unraid 7.2.0 / Docker 27.5.1 with **no compose on the host**; appdata
  `/mnt/user/appdata`, media `/mnt/user/Media`, LAN `192.168.1.195`, tailscale
  `tower`. Already two-tier: Portainer runs plex + gluetun/qbittorrent from
  compose, unraid's Docker tab runs the rest. The gluetun sidecar is **already
  in place**; provider is NordVPN, which has no port forwarding. PUID/PGID
  diverge three ways. Homepage does not exist at all.

## Not yet specified

- **Migrating the remaining services** — now *seven*, not four: sonarr, radarr,
  prowlarr, qbittorrent, gluetun, plex, calibre, lazylibrarian. Deliberately
  fog: until homepage proves the layout and the reconcile loop, we don't know
  whether this is one repetitive ticket or one per service. What ticket 01 did
  sharpen is that they are **not uniform** — plex, gluetun and qbittorrent
  already have compose definitions in Portainer's appdata to lift, while the
  other five exist only as unraid template XML and must be translated. Plex is
  the awkward one (20G appdata, `/dev/dri` passthrough, claim token). Graduates
  once [08 — Deploy homepage from the repo](issues/08-deploy-homepage.md)
  resolves.
- **Image update strategy.** Renovate is the habit from home-ops, but whether it
  fits depends on how the reconcile mechanism reads tags. Ticket 01 raised the
  stakes: every image is on `latest` and 5–8 months stale, so nothing is
  updating today. Revisit after
  [02 — Choose the reconcile mechanism](issues/02-choose-reconcile-mechanism.md).
- **Appdata backup and box rebuild.** Once container definitions are in git, the
  remaining single point of failure is appdata — 24G of it, dominated by plex's
  20G. What backs it up, and what a rebuild-from-scratch actually takes, is
  unclear until the layout exists.
- **Secret rotation and hygiene on the box.** Ticket 01 found the NordVPN
  WireGuard key and the calibre GUI password sitting in plaintext on `/boot` and
  in Portainer's appdata, and leaked both in the process of reading them. Once
  [03](issues/03-secrets-handling.md) picks a mechanism, there is a follow-on
  question about what happens to the plaintext copies left behind.
- **Publishing to GitHub.** Known future step, deliberately deferred until a few
  investigation tickets have landed.
- **Monitoring and alerting** for the stack. Suspected, unsharp; may fall out of
  scope entirely once the stack is running.

## Out of scope

- **Decommissioning or migrating `~/home-ops`.** The k8s cluster is a different
  site and stays as it is. If it is ever retired, that is a fresh effort with
  its own destination.
- **Unraid array, share and disk configuration.** This map governs containers
  and their config, not the storage layer underneath them.
