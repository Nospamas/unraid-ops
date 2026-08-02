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

**[04](04-reverse-proxy-and-domain.md) adds a ninth image that neither candidate
covers.** Caddy is **built**, not pulled — an `xcaddy` multi-stage Dockerfile in
this repo. Komodo's `auto_update` watches registry digests and so cannot see it
at all, and Renovate has to track *two* moving parts rather than a tag: the base
`caddy` image tag **and** the `caddy-dns/cloudflare` Go module in the `xcaddy`
line. Renovate does understand Dockerfile `FROM` lines and Go modules, but this
needs saying out loud in the answer rather than being assumed. Settle what
"update" means for a built image, and what triggers a rebuild.

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

## Narrowed by [07](07-repo-layout-and-conventions.md)

07 settled the *format* of a tag and in doing so settled most of the choice
above. Images are written **version + digest in one string** —
`sonarr:4.0.19.2995@sha256:e679d9…`, the verified `~/home-ops` convention. That
is what Renovate bumps, and Komodo's `auto_update` path wants bare `latest`, so
**the first candidate has effectively won**: git names what is running.

What is left here is real but smaller:

- **Confirm or overturn** that reading. If `auto_update` is still wanted for some
  services, say so now — it means abandoning the digest pin for those, and 07's
  layout would need a matching exception.
- **Cadence and blast radius**, grouping, and whether plex and gluetun are
  handled differently. Untouched by 07.
- **What "update" means for the built Caddy image** — 07 confirmed it is the
  **sole bare-tag exception**, because it never reaches a registry and so has no
  digest to pin. Renovate must instead track the base `caddy` tag in the
  Dockerfile *and* the `caddy-dns/cloudflare` Go module in the `xcaddy` line, and
  a bump has to trigger a Komodo `Build`, not just a redeploy.
- **The seam with [13](13-local-tooling.md)** is unchanged: one `renovate.json`,
  two datasources, whoever lands second extends it.

## Added by [13](13-local-tooling.md)

13 landed first, so **[.renovaterc.json5](../../../.renovaterc.json5) already
exists** — note the filename, which is home-ops' and not the `renovate.json` the
tickets had been saying. It is scoped to the **mise** and **github-actions**
managers, with `ignorePaths: ["**/*.sops.*"]`, `schedule: ["every weekend"]`, the
dependency dashboard on, and auto-merge for minor/patch after a 3-day
`minimumReleaseAge`. Extend it; do not rewrite it.

Two facts that change this ticket's shape:

- **Renovate is live on this repo** as of 2026-08-02 — it joined the existing
  `Nospamas` account installation, and its dashboard is
  [#1](https://github.com/Nospamas/unraid-ops/issues/1). Nothing needs minting or
  enabling. It already parses the `version@digest` action pins correctly, which is
  direct evidence the same format will work for image tags. Note it reads
  **seven** mise tools, not eight: `gh = "latest"` has no version to track, so a
  bare tag is invisible to Renovate — the same reason 07's digest pinning matters
  here, now demonstrated rather than argued.
- **`helpers:pinGitHubActionDigests` is already extended**, and the two actions in
  [.github/workflows/lint.yaml](../../../.github/workflows/lint.yaml) are pinned
  by commit digest with the version in a trailing comment. That is the same
  version-plus-digest habit 07 chose for images, so whatever this ticket decides
  for image tags should read consistently with it.
