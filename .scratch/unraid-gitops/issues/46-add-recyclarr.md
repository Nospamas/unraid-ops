---
id: "46"
title: Add recyclarr
type: task
status: closed
description: >
  recyclarr runs from git and owns quality profiles, custom formats and quality
  definitions — naming stays hand-set, because a silent revert there reaches
  files on disk. The premise was wrong: nothing was drifting, both *arr held
  zero custom formats, so this introduced a 2160p policy rather than codifying
  one. First headless Stack, so it declares `x-watch` instead of a probe.
touches:
  [
    stacks/recyclarr/,
    docs/adding-a-service.md,
    docs/conventions.md,
    komodo/procedures.toml,
  ]
---

# 46 — Add recyclarr

Blocked by: —
Resolved: 2026-08-07

## Question

Picked in [45](45-pick-from-the-survey.md), surveyed in
[40](40-survey-complementary-services.md). `recyclarr/recyclarr:8.7.1` syncs
TRaSH-guides custom formats and quality profiles into sonarr and radarr on a
schedule, because those profiles are hand-set today and drift.

**Two decisions come before the routine**, and neither is a taste call.

### Say which settings it owns

This ticket was first written claiming recyclarr contradicts
[CONTEXT.md](../../../CONTEXT.md). **It does not, and the doc has been corrected**
— reconciled or in appdata is a per-service choice, the default is appdata, and
homepage was never an exception to a rule. So there is no permission to seek.

What is left is the real question and it is narrower: **which settings recyclarr
owns.** It writes custom formats, their scores and the quality profiles that
carry them; it does not touch indexers, root folders or download clients. Write
that boundary down where a person hunting for it will find it, because the
failure mode is silent — someone tunes a quality profile in sonarr's UI and the
next sync reverts it with no error anywhere.

Which also settles whether the `recyclarr.yml` is a `config_files` entry: it is
git-owned settings, so it is listed, or a push that edits it is invisible to the
loop.

### It is the first Stack with nothing to probe

The fog [40] surfaced is now this ticket's. Recyclarr is a scheduled job with no
listener: no `caddy` label, no hostname, no homepage tile with anything on it,
and **no HTTP endpoint** — where all sixteen probes in
[stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml) are HTTP.
[docs/adding-a-service.md](../../../docs/adding-a-service.md) ends every service
at those three things and has no answer for a Stack that has none of them.

Decide how this repo knows a headless Stack is alive, and write it into the
routine — it applies to Kometa and anything else scheduled, not just this one.
`caddy.import: internal` is never dropped to satisfy the lint; check what
`scripts/check-exposure.sh` actually requires of a Stack with no caddy label at
all before assuming it needs an exemption.

### Then the routine

Per [docs/adding-a-service.md](../../../docs/adding-a-service.md), **new** flavour.
Known specifics:

- Both API keys are secrets — `just secret recyclarr`, never `sops --encrypt`.
- Its config is a `recyclarr.yml`. **Bind the directory, never the file.**
- Sonarr and radarr are reached by container name on `shared`.
- Add the Stack to the `BatchDeployStackIfChanged` list in
  [komodo/procedures.toml](../../../komodo/procedures.toml) — explicit, never `*`
  — then `just reconcile`, not the cron.
- A green reconcile is not a running service. Check it actually synced something.

## Answer

### The premise was wrong: nothing was drifting

The ticket says the profiles "are hand-set today and drift." **Asked the box
instead of reasoning about it**, the way [45] learned to. Both *arr held
**zero custom formats** and only the six stock quality profiles — `cf=0 min=0
cutoffScore=0` across the board, untouched since install.

So recyclarr is not codifying a policy that existed. It **introduces one that
did not**, and the whole silent-revert framing pointed at the wrong half of the
settings: what *had* been hand-tuned was the naming, in both apps, already set
to TRaSH's scheme with renaming ON.

That inverted the boundary question. rb's ruling:

| owned by git | left in appdata |
|---|---|
| quality profiles | media naming |
| custom formats and their scores | media management |
| quality definitions (size limits) | indexers, root folders, download clients |

**Naming is out precisely because it is the only half anyone had tuned**, and a
silent revert there reaches files on disk rather than a settings page. The
recyclarr schema exposes `media_naming` and `media_management` as separate keys,
so leaving them absent is the whole mechanism — recyclarr writes only what the
config lists.

An earlier reading of this ticket called radarr's uncapped Bluray-1080p/2160p
tiers a deliberate edit worth protecting. **It was not** — the sync's own diff
shows sonarr carrying the same `max=null` shape as a stock default. The claim
was wrong; the decision it fed into did not depend on it.

The boundary is written in three places, because the person hunting for it is
someone whose UI edit just vanished:
[conf/recyclarr.yml](../../../stacks/recyclarr/conf/recyclarr.yml)'s header, a
**Traps** entry in [adding-a-service.md](../../../docs/adding-a-service.md)
beside plex's and calibre's, and the `config_files` entry that makes an edit to
it reach the box at all.

### The policy this introduces is 2160p, and it governs nothing yet

rb picked UHD: `WEB-2160p` for sonarr, `UHD Bluray + WEB` for radarr, both with
`reset_unmatched_scores` on so the profile is wholly the repo's rather than a
merge with whatever sonarr holds.

The first sync created 38 custom formats and the profile in sonarr, 55 and the
profile in radarr, and rewrote 14 quality definitions in each. **Verified against
the *arr's own API, not recyclarr's report** — and the same check confirmed the
boundary held: both naming configs are byte-identical to before the sync.

**But every library item is still on profile 1, `Any`** — 187 series and 1736
movies. The policy exists and governs nothing. That is deliberately left as a
hand-off rather than done here, because it is not a chore: the array is at 36T
used of 59T with 23T free, and 1736 movies currently average 14G. Moving them
onto a UHD profile wholesale queues an upgrade backlog that does not fit.

### What watches it: nothing, and that is argued rather than inherited

`check-exposure.sh` requires **nothing** of a headless Stack — it walks `caddy:`
hostnames and `ports:` blocks, and this Stack has neither. `check-probes.sh` the
same. There was no exemption to seek; the lint is simply **silent** here, and
that silence is the gap rather than the obstacle.

Two candidate watchers were checked and both fail on the facts:

- **Komodo.** [40]'s fog asked what `StackStateChange` sends for an *exited*
  single-container Stack. Moot — recyclarr's image defaults to **cron mode** and
  the container stays `Up` indefinitely, so a failed sync changes no container
  state at all. Komodo's `Unhealthy` is *"containers are in a mix of states"*,
  nothing to do with docker healthchecks, so a `healthcheck:` block would be
  consumed by nobody.
- **Recyclarr reporting itself.** It can notify per sync, warnings-and-errors
  only — but only through an Apprise API server, a whole Stack whose one job is
  relaying. And it inherits [49](49-renovate-never-saw-linuxserver.md)'s exact
  flaw: recyclarr dying sends nothing, and silence reads as health.

So: **nothing watches it**, stated on the Service as `x-watch` and earned rather
than assumed — a stopped sync leaves the *arr on their last-synced settings,
which is stale policy rather than a broken service, and no worse than the state
the box was in before this Stack existed.

**The ruling is per-Stack, argued each time**, not a blanket "headless is
unwatched". [48](48-add-unpackerr.md) inherits nothing: its failure stalls
imports. Step 7c of the routine now forces the sentence and says what it has to
answer — how bad the silence is, and what would surface it anyway.

**This is not the `x-unprobed:` that [44] drafted and dropped.** That would have
been an opt-out from a check that *could* have run, and 44's objection stands —
an escape hatch that exists gets used. `x-watch` grants no exemption, because
there is no probe to be exempt from; it demands a sentence where the alternative
is silence. What it lacks is teeth, which is
[53](53-lint-the-headless-statement.md).

### Build notes

- **Not a linuxserver image** — recyclarr reads no `PUID`/`PGID`. `user:
  "${PUID}:${PGID}"` plus the `mkdir`/`chown` in `pre_deploy`, per the trap [11].
- **`state/` cannot be relocated.** `RECYCLARR_DATA_DIR` moves only `resources/`
  and `logs/`; state stays in the config dir. So `/config` is appdata and
  **writable**, and the git-owned half mounts read-only at `/config/configs` —
  every `*.yml` there is loaded as if passed to `--config`, which is the feature
  recyclarr ships for exactly this. Directory, never the file.
- **The API keys are a second copy** of homepage's. Unavoidable — recyclarr must
  authenticate — but it raises the rebuild cost the fog already tracks: rotating
  an *arr key now touches two encrypted files.
- **No Renovate rule needed.** The tag is plain `8.7.1`, which default `docker`
  versioning orders correctly; [49]'s `regex:` rules are a linuxserver problem.
- **Cron mode does not sync at start**, so the deploy was inert and the first
  sync was a deliberate separate act, previewed before it ran.

### Verified

`just lint` green, `just verify-secrets` green, container `Up`, config mounted
read-only where recyclarr finds it, and the sync's effects read back out of
sonarr's and radarr's APIs rather than trusted from its log.

## Hand-offs

- **Assign the new profile to whatever should use it.** All 187 series and 1736
  movies sit on `Any`; the 2160p profiles govern nothing until moved, and moving
  them all at once does not fit in 23T free.
