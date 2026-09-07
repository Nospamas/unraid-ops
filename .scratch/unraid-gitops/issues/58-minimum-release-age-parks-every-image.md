---
id: "58"
title: minimumReleaseAge parked every container image, because ghcr.io has no timestamps
type: task
status: closed
description: >
  Renovate reads release dates only from Docker Hub's `tag_last_pushed`, and
  under the default `timestamp-required` a missing one is pending *forever* — so
  the 3-day soak on the container rule held every image on the dashboard under
  "Pending Status Checks", which names Renovate's internal checks rather than a
  CI check. Dropped; ghcr.io stays, since the alternative was moving the lookup
  to Docker Hub and [49]'s reasons for ghcr still hold.
touches:
  - .renovaterc.json5
---

# 58 — `minimumReleaseAge` parked every container image

Resolved: 2026-09-07
Blocked by: —

## Question

Plex had not been offered an update. [49](49-renovate-never-saw-linuxserver.md)
fixed the versioning that made linuxserver bumps invisible, and the fix works —
the dashboard shows plex resolving `1.43.3.10861-07dfddaeb-ls318` →
`1.43.3.10896-cb3ebc72d-ls322`. It just never became a branch.

## Answer

### It was not waiting on a status check

The dashboard listed plex under **Pending Status Checks**, which reads like CI.
It is not: Renovate files its own *internal* checks — `minimumReleaseAge` and
`minimumConfidence` — under that heading. No branch is pushed while an entry sits
there, so there was nothing for [lint.yaml](../../../.github/workflows/lint.yaml)
to run against, and its `pull_request` trigger could not have fired anyway.

### A missing timestamp is pending forever, not pending for three days

The chain, from Renovate's source:

- The `docker` datasource populates `releaseTimestamp` from Docker Hub's
  `tag_last_pushed` field and nowhere else — its own `releaseTimestampNote` says
  *"Only supported on Docker Hub"*. ghcr.io is a plain OCI registry with no such
  field, and the datasource implements no `postprocessRelease`, so there is no
  second chance to fetch one.
- [`checkMinimumReleaseAge`](https://github.com/renovatebot/renovate/blob/main/lib/util/minimum-release-age.ts)
  with no timestamp returns `isPending: minimumReleaseAgeBehaviour === 'timestamp-required'`
  — and `timestamp-required` is the **default**.
- Every candidate therefore pends, so `filterInternalChecks` takes the highest
  and sets `pendingChecks = true`, because `internalChecksFilter` defaults to
  `strict`.

Measured, not inferred: `-ls322` was built **2026-08-31** and was still parked on
a dashboard refreshed **2026-09-06**. Seven days against a three-day soak. The
`-ls323` build is not evidence of anything — it landed 2026-09-07, after that
refresh.

### The two that escaped prove the mechanism

`matchUpdateTypes: ["minor", "patch"]` scoped the rule, so the only updates that
got through were the ones it did not cover: caddy's **digest** bump (PR #6) and
calibre's **major**, which stopped at [49]'s `dependencyDashboardApproval`
instead. Everything else — bazarr, prowlarr, radarr, sonarr, qbittorrent,
tautulli, homepage, unpackerr, recyclarr, komodo — was held.

### Dropped rather than worked around

Three options, and the soak is worth least of them:

- **`minimumReleaseAgeBehaviour: "timestamp-optional"`** keeps the gate where a
  timestamp exists and waves through where it does not. It leaves a check in the
  config that silently does nothing for most of the repo, which is the shape of
  failure [49] and [44] already cost.
- **`internalChecksFilter: "flexible"`** creates the branch anyway, defeating the
  gate everywhere including where it works.
- **Dropping it** is honest: no soak, and the config does not claim one.

The reconcile loop is the real delay in any case — [57](57-reconcile-once-a-day.md)
put deploys at 3am daily, so an automerged bump waits up to 24h before it reaches
the box, unattended or not.

`mise` and `github-actions` keep their three days. `github-releases` and
`github-tags` both declare `releaseTimestampSupport = true`, so those gates work.

### Moving the lookup to Docker Hub was the alternative, and was declined

Docker Hub is the only source Renovate can read dates from, so `registryAliases:
{ "lscr.io": "docker.io" }` would have bought a real soak. Verified rather than
assumed: all 20 pinned digests resolve byte-identically on ghcr.io and Docker Hub
(`serfriz/caddy-cloudflare-dockerproxy` looks like an exception only because its
`2.11.4` tag was re-pushed — the two registries agree with each other, and PR #6
is that digest move); Docker Hub sorts newest-first, so plex's newest `-lsNNN`
tag is on page 1 of 2637; and every API call in this investigation succeeded
anonymously.

Declined anyway. It undoes [49]'s registry decision to buy a soak that [57]'s
daily reconcile already provides, and it costs two things:

- **`matchPackageNames` moves again**, to `docker.io/linuxserver/**`. Traced
  through `getDep` → `splitImageParts` → `getRegistryRepository`: the packageName
  becomes `docker.io/linuxserver/plex`, and `https://docker.io` normalises to
  `https://index.docker.io`, the `DOCKER_HUB` constant gating the Hub tags API.
  This is precisely [49]'s silent trap, one registry over, and nothing in
  `just lint` can catch a `matchPackageNames` that matches nothing.
- **Two images have no Docker Hub twin at their path** — `ghcr.io/twin/gatus`
  and `ghcr.io/unpackerr/unpackerr` — so they would need the
  `timestamp-optional` exception regardless.

[49]'s reasons for ghcr.io — the `hostsNeedingAllPages` override and the
credential Renovate provisions from its own GitHub token — still hold, and the
outstanding `read:packages` PAT it recorded is unaffected.

## What this leaves

- **The `dependencyDashboardApproval` rule is still there**, still marked
  TEMPORARY by [49]. calibre's major is the last thing behind it.
- **Nothing caught this either.** [49] was silent for months; this was silent
  since [49] landed, and looked *more* benign — "Pending Status Checks" reads as
  work in progress. Second instance of the same class, and it strengthens the
  watchdog-beside-Renovate question in the map's fog: Diun watches build tags and
  would have noticed nine images going nowhere.
- **`renovate-config-validator` still cannot run here** — no node, no docker
  socket, the limit [12] and [49] both recorded. `just lint` passes and the file
  parses; schema validation falls to the next Renovate run.
