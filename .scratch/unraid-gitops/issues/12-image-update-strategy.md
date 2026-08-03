# 12 — Decide the image update strategy

Type: grilling
Status: closed
Assignee: Nospamas
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

## Resolution

**Renovate, and only Renovate.** 07's reading confirmed and hardened: Komodo's
`poll_for_updates` / `auto_update` are used **nowhere**, and could not be even if
wanted — a `version@digest` pin cannot drift, so polling has nothing to find. The
two candidates were never really two; digest pinning decided it.

Config landed in [.renovaterc.json5](../../../.renovaterc.json5), extending 13's
file rather than replacing it. Images inherit the existing `every weekend`
schedule, deliberately: an automerged bump then deploys on the next poll while
someone is around, not midweek at 3am.

### Automerge, and the carve-outs

Minor + patch automerge, matching mise and Actions. Four things are pulled back
to human merge because a bad version is expensive and nothing is watching —
**monitoring is still fog**:

| human-merged | why |
| --- | --- |
| `stacks/download/**` | [06](06-qbittorrent-vpn-topology.md)'s hazard: recreating gluetun leaves qbittorrent in a dead netns, **silently**, and whether Komodo's Deploy recreates both unaided is still unverified |
| `stacks/plex/**` | server bumps break clients; [09](09-unify-uid-gid.md) also left `/dev/dri` under uid 99 as a check, not an assumption |
| `stacks/caddy/**` | fronts every `*.rbrb.in` hostname |
| `stacks/coredns/**` | answers those hostnames on the tailnet |
| `bootstrap/**` | see below |

So automerge covers the four *arr, calibre and homepage. `digest`-only updates
are **not** automerged for anything (mise/actions keep theirs) — deliberate, and
cheap, because the one image whose tag is rebuilt in place is Caddy, which is
human-merged regardless.

**Grouping is one PR per Stack directory**, matching 07's deploy atom so a merge
maps 1:1 to a redeploy. Implementation is smaller than the rule sounds: Renovate
already defaults to one PR per dependency, and every Stack holds one image
*except* `download` — so this needed **one** group rule, not one per Stack, and
adding a Stack needs no config edit.

### Bootstrap is not GitOps'd, on purpose

The ticket had not noticed that Renovate's `docker-compose` manager (on by
default via `config:recommended`) already matches
[bootstrap/compose.yaml](../../../bootstrap/compose.yaml) — so image bumping was
**already live**, on the one stack nothing reconciles.

The obvious fix was to make bootstrap a Komodo Stack. It was investigated and
**declined on evidence**:

- Komodo Core **can** redeploy itself — Periphery does the work, and the update
  log only *looks* failed because Core restarts mid-deploy
  ([discussion #223](https://github.com/moghtech/komodo/discussions/223)).
- **Periphery cannot.** Redeploying it kills the process running the deploy. The
  maintainer's own answer is to keep Periphery out of the Core stack entirely; he
  runs it under systemd.
- They are a **pair**: upstream's
  [version-upgrades doc](https://komo.do/docs/setup/version-upgrades) says some
  Core upgrades *"require updating the Periphery binaries to match the Core
  version before this functionality can be restored."*

So the half that can automate is chained to the half that cannot, and
self-management buys only a window where Core is ahead of Periphery. **`bootstrap/`
therefore never gets a `komodo.toml`** — recorded in
[docs/repo-layout.md](../../../docs/repo-layout.md) and
[bootstrap/README.md](../../../bootstrap/README.md) as a deliberate choice, not
an oversight for someone to tidy up later.

Flow: Renovate raises a **pair-grouped** PR (`komodo` = Core + Periphery;
`ferretdb` = FerretDB + postgres-documentdb, which name each other in their tags),
never automerged. **Merge, then apply on the box** by hand. The alternative order
— apply then merge, keeping git never ahead of the box — was put and declined.
The accepted cost is a window where `main` claims a version the box is not
running, mitigated by `prBodyNotes` stamping the SSH steps into the PR body so
the instruction is in front of you at the moment you merge. A `just
bootstrap-check` drift recipe was offered and declined as ceremony.

### Caddy: the build is gone entirely

The biggest change, and it overturns two closed tickets.

[04](04-reverse-proxy-and-domain.md) chose to build Caddy on the box via a Komodo
`Build`; 07 made the resulting image *"the only place a bare tag is allowed."*
The human's standing rule — **building our own images should be exceptionally
rare, and when needed it happens in GitHub Actions, never on the box** — sent
this back for evaluation of prebuilt options. Four were assessed:

| candidate | both modules | versioned tags | maintenance | verdict |
| --- | --- | --- | --- | --- |
| `zenjoy/caddy-cloudflare-proxy` | — | — | **repo 404** | dead |
| `qcts33/caddy-docker-proxy-cloudflare` | ✗ no docker-proxy, despite the name | ✓ | 0★ | fails requirement |
| `KingPin/caddy-docker-cloudflaredns` | ✓ | ✗ **`latest` only** | 2★, 0 forks | cannot do `version@digest` |
| **`serfriz/caddy-cloudflare-dockerproxy`** | ✓ | ✓ semver, auto-built per Caddy release + monthly module refresh | 334★, builds ran hours before assessment | **adopted** |

Its Dockerfile is byte-for-byte the build we would have written:

```dockerfile
FROM caddy:2.11.4-builder AS builder
RUN xcaddy build \
    --with github.com/caddy-dns/cloudflare \
    --with github.com/lucaslorentz/caddy-docker-proxy/v2
FROM caddy:2.11.4
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
CMD ["caddy", "docker-proxy"]
```

Building our own would be a strict duplicate with more machinery and *slower*
tracking. **Keep those four lines** — they are the escape hatch if serfriz goes
stale, and then the build goes in Actions and pushes to GHCR.

Consequences: **no image in this repo is built**, `stacks/caddy/Dockerfile` and
its `[[build]]` are void, the reconcile Procedure needs no build stage, and 07's
bare-tag exception is deleted rather than narrowed. [16](16-deploy-caddy.md)
amended accordingly (and retitled — it no longer builds anything).

Supply chain, stated plainly rather than waved through: effectively a single
maintainer, no provenance attestation. Bounded because the token it holds is
**zone-scoped DNS-edit on `rbrb.in` only** — no box, no tailnet, revocable at
Cloudflare — the tags are mutable but we pin by digest, so a silent rebuild
surfaces as a human-merged PR, and the Dockerfile is four auditable lines.

### Files touched

- [.renovaterc.json5](../../../.renovaterc.json5) — five new `packageRules`.
- [docs/repo-layout.md](../../../docs/repo-layout.md) — bare-tag exception
  deleted, *Built images* rewritten to "nothing is built", bootstrap's
  no-`komodo.toml` rule stated.
- [bootstrap/README.md](../../../bootstrap/README.md) — new *Updating these four
  images* section.
- [16](16-deploy-caddy.md) — Dockerfile and `[[build]]` struck; also corrected a
  stale `task lint` and a `check-exposure.sh` line 13 had already done.

**Verification is partial, and this matters.** `just lint` passes. The config
parses and the seven `packageRules` are in the right order — the broad automerge
rule precedes every carve-out, so the later rules win as Renovate requires. But
`renovate-config-validator` **could not be run**: there is no node on the laptop
and this user cannot reach the docker socket. Schema validation therefore falls
to Renovate's own next run, which reports config errors on
[dashboard #1](https://github.com/Nospamas/unraid-ops/issues/1) — **check it.**

Beyond that, **nothing is verified against a live Renovate run**, because
`stacks/` is still empty — these rules are written ahead of the files they match and go live as
Stacks land. The first Stack to arrive ([08](08-deploy-homepage.md)) is the first
real test of them. No new secrets.
