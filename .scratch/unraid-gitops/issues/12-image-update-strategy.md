# 12 — Decide the image update strategy

Type: grilling
Status: open
Blocked by: 07

## Question

Graduated out of the fog by [02](02-choose-reconcile-mechanism.md), which made
the question sharp by revealing that the chosen mechanism has its own answer
built in — so this is now a genuine two-way choice, not an open-ended one.

[01](01-inventory-running-containers.md) set the stakes: **every image on the
box is `latest` and 5–8 months stale.** Nothing updates today. Whatever is
decided here is a real change, not a formalisation.

The two candidates:

- **Pin tags in git + Renovate.** The home-ops habit. Renovate opens a PR per
  image bump; merging it is the push that reconciles the box. Updates are
  visible, reviewable, and revertible by `git revert` — the version history of
  the box lives in git. Cost: a bot with access to the remote from
  [10](10-publish-repo-to-remote.md), and eight services' worth of PR noise.
- **Leave `latest` + Komodo's native `auto_update`.** Komodo Stacks have
  `poll_for_updates` (show an indicator when a newer image digest exists) and
  `auto_update` (redeploy when one does), with `auto_update_skip_services` to
  exempt individual services. Zero extra machinery. Cost: the running image is
  whatever digest happened to be `latest` at poll time — git no longer records
  what is actually running, and rolling back means finding a digest by hand.

The second cost is the crux, and it cuts against the destination: if git does
not name the version, git does not fully describe the box.

Settle:

- **Which of the two**, or a split — e.g. pinned + Renovate for the *arr and
  qbittorrent, `auto_update` for the ones where a bad version is cheap to
  absorb.
- **Whether plex is an exception.** It already has a pinned `VERSION` and a
  `/dev/dri` passthrough; plex server updates can break clients, so it may want
  pinning regardless of what the others do.
- **What "update" means for gluetun**, where a bad version means no VPN, which
  means either no torrenting or — worse, depending on
  [06](06-qbittorrent-vpn-topology.md)'s kill-switch answer — leaking.
- **Cadence and blast radius** — all eight at once, or staggered.

Blocked by [07](07-repo-layout-and-conventions.md) because the layout decides
*where* a tag is written, and Renovate can only bump what it can find.
