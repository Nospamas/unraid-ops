---
id: "49"
title: Renovate has never offered a linuxserver update
type: task
status: closed
description: >
  Not the 429s — Renovate's default `docker` versioning requires a candidate's
  suffix be identical, and `-lsNNN` increments every build, so the only
  compatible tag was the one already pinned. Fixed with `regex:` versioning and
  a `registryAliases` to ghcr.io, the name Renovate recognises; lazylibrarian
  cannot be versioned at all and is off.
touches: [.renovaterc.json5, docs/conventions.md]
---

# 49 — Renovate has never offered a linuxserver update

Resolved: 2026-08-07

## Question

Renovate began logging `429 TOOMANYREQUESTS` against `lscr.io`, then
`Failed to look up docker package ... no-result` for bazarr, plex and radarr.
The presenting question was rate limiting: it runs hourly, and hourly looked like
too much.

It was not rate limiting, and the drift was much older than the 429s. Against
linuxserver's own version API:

| | pinned | current |
| --- | --- | --- |
| calibre | `v8.15.0-ls371` | `v9.13.0-ls415` |
| radarr | `6.0.4.10291-ls288` | `6.3.0.10514-ls313` |
| prowlarr | `2.3.0.5236-ls133` | `2.5.2.5491-ls156` |
| sonarr | `4.0.16.2944-ls298` | `4.0.19.2979-ls320` |

calibre is a **major** version behind and is on the automerge list. Those PRs
were never raised.

## Resolution

**Renovate has never once been able to offer a linuxserver update**, since [21]
landed the first of them. The 429s are recent noise on top of a lookup that could
not have produced a bump in any case.

Renovate's default `docker` versioning splits a tag on `-`, keeps the first piece
as the version and **everything after it as a "suffix"**, then filters candidates
through `isCompatible`, which requires the suffix be *identical*
([`versioning/docker`](https://github.com/renovatebot/renovate/blob/main/lib/modules/versioning/docker/index.ts),
enforced at
[`lookup/index.ts`](https://github.com/renovatebot/renovate/blob/main/lib/workers/repository/process/lookup/index.ts)
— *"Leave only compatible versions"*). linuxserver's `-lsNNN` build counter lives
in that suffix and increments on **every** build. Simulated against the real tag
lists, all nine images:

```
image           total  parse  compat  newer
sonarr           6266    436       1      0     ← the "1" is the pinned tag itself
radarr          15581    698       1      0
calibre          2321    725       1      0
```

The failure has no signature — no error, no dashboard entry, no PR. It is the
same shape as [44]'s missing probe: correct-looking config doing nothing.

### The arch tags were never the risk

The question that surfaced this was whether Renovate might pick `amd64-…` over
the multi-arch tag. It cannot: `_parse` requires the first `-`-delimited piece to
match `^\d+(\.\d+)*\w*$`, so `amd64-`, `arm64v8-`, `version-` and `nightly-` all
fail to parse and are discarded. The pinned digests are also multi-arch
**indexes** (`oci.image.index.v1+json`, linux/amd64 + linux/arm64), so the arch is
resolved at pull. Both halves were already right — the same gate was simply
discarding everything else too.

### `regex:` versioning, three rules

`loose` was tried first and is **worse than nothing** — it accepts
`6.4.2-nightly`, `20.04.1` (an Ubuntu tag qbittorrent carried in 2021) and bare
git hashes. The `-ls(?<build>\d+)$` anchor is what restricts the candidate set to
the static build tags [linuxserver tells you to
pin](https://www.linuxserver.io/blog/docker-tags-so-many-tags-so-little-time).

Two traps, both silent:

- **`revision` is only counted when `build` is also captured.** Map the ls
  counter to `build`, never `revision`, or three-part tags like `v2.17.2-ls238`
  compare equal to `v2.17.2-ls239` and ls-only bumps vanish.
- **`matchPackageNames` matches `packageName`**, which `registryAliases` has
  already rewritten. Spelling the rules `lscr.io/**` matches nothing at all.

qbittorrent needs its own tighter anchor: its tag has carried three shapes
(`4.4.0202011011649-7112-…ubuntu18.04.1-ls105`, `5.1.2-r4-ls426`, now
`5.2.3_v2.0.13-ls469`), and the general pattern reads the 2021 ones as version 14
and offers a five-year rollback as a major bump.

**lazylibrarian is off.** `ef1f6e73-ls222` is an upstream git hash and a counter,
with no version anywhere. Ordering on the counter alone fails too: `262e8e14-ls328`,
`6a767ee9-ls328`, `8d0f0934-ls328` and `3334ef0d-ls328` are four different digests
sharing one ls number, so it cannot name a newest. Disabled rather than pinned to
a lie — it moves by hand.

### `lscr.io` → `ghcr.io`, for lookup only

`lscr.io` is ghcr.io wearing a different name: same `www-authenticate` realm,
same `x-github-request-id`, and every one of the nine pinned digests verified
byte-identical across `lscr.io`, `ghcr.io` and `docker.io`. But Renovate has never
heard of the alias, and that costs two things it gives `ghcr.io` for free:

- GHCR returns tags **oldest-first**, so the newest is on the last page. Renovate
  hardcodes `ghcr.io` (with `quay.io` and `cgr.dev`) in `hostsNeedingAllPages`
  and fetches 1000 pages for it; an unrecognised host gets `dockerMaxPages`,
  default 20. radarr is 15.5k tags over 16 pages and climbing — so the cliff was
  never GHCR's, it was the alias hiding GHCR's identity.
- The ghcr.io credential is provisioned from Renovate's own GitHub token. Under
  the alias the request went out anonymous — the log's `"authorization": false` —
  into a shared bucket. That is the 429.

Not fixable at the registry: GHCR implements only the OCI spec, which defines no
ordering. `ordering`, `sort`, `order`, `page` and `reverse` all return
byte-identical output and `n` caps at 1000 regardless. **Authenticating fixes the
429, not the order.**

Docker Hub was the first answer and was overturned. Its API does sort
newest-first and Renovate keeps an incremental `DockerHubCache` for it, so it
reads one page instead of sixteen — but it needs a Docker Hub account this repo
otherwise has no use for, and it buys nothing the `hostsNeedingAllPages` override
does not already give. The images keep pulling from `lscr.io` either way:
`registryAliases` rewrites only the lookup, because `replaceString` retains the
original line and only the tag and digest are templated.

### Ruled out

- **Swapping to `ghcr.io/linuxserver/*` in the compose files.** Done, then
  reverted: it fixes a bot problem in the wrong repo, and `lscr.io` is what
  linuxserver documents and what [adding-a-service.md](../../../docs/adding-a-service.md)
  would tell the next person to write.
- **`# renovate:` annotations with a custom manager.** The annotation is inert
  without a `customManagers` regex, and home-ops' block captures the *entire*
  image reference as `currentValue` on a compose `image:` line. Adopting it means
  reimplementing the docker-compose manager, and silently breaking the
  `matchManagers: ["docker-compose"]` rule that automerges images. It also does
  not touch versioning, which was the actual bug. Its niche is a version no
  manager can see — `bootstrap/` pinning a downloaded binary — and there is
  none today.
- **`datasource=github-releases`.** linuxserver's `docker-*` repos tag releases
  with the exact image tag, so version detection would work in one API call. But
  its `getDigest` returns the **git commit SHA** of the tag, which written into an
  `@sha256:` slot is an image reference that exists in no registry. Only the
  `docker` datasource produces a manifest digest, so any route keeping [12]'s pin
  must end at a registry.
- **Diun instead of Renovate.** It notifies; it cannot resolve a digest or write
  a file, so it is [12]'s declined `poll_for_updates` with a nicer notification.
  As a *watchdog beside* Renovate it is a real proposal — this failure was silent
  for months and nothing caught it — and is left in the map's fog.

### Staged, on purpose

The fix unblocks updates never once offered, so the first run raises a year of
them at once — radarr and prowlarr a minor each, calibre a major, qbittorrent
taking the download stack and gluetun with it ([06]). A **temporary**
`dependencyDashboardApproval` rule holds all nine behind a tick on
[dashboard #1](https://github.com/Nospamas/unraid-ops/issues/1) so the backlog
arrives as a list rather than as four unattended redeploys. **It is marked
TEMPORARY and must be deleted** — while it stands, no linuxserver image can
automerge, including routine patches.

### Verification

Every claim measured, not read: digests compared across three registries, tag
lists paginated in full, and Renovate's `docker` versioning, `regex` versioning
and `loose` versioning each reimplemented and run over the real tag lists. The
`regex:` results match linuxserver's version API exactly for all eight versionable
images.

`renovate-config-validator` **could not be run** — still no node and no docker
socket, the same limit [12] recorded. The file parses and `just lint` passes;
schema validation falls to Renovate's next run, which reports config errors on
dashboard #1.

## What this leaves

- **The home-ops Renovate still has no ghcr.io credential.** Caching landed
  (`RENOVATE_CACHE_DIR` on a PVC, `repositoryCache`, four docker namespaces at a
  24h soft TTL), which cuts how often it asks. It does not authenticate, and the
  429 is an auth problem. A `hostRules` entry with a classic PAT scoped
  `read:packages` is still outstanding.
- **The `dependencyDashboardApproval` rule must be removed** once the backlog is
  drained.
- **Nothing watches for this failure returning.** Renovate going quiet looks
  exactly like nothing being released. Diun-as-watchdog is in the map's fog.
