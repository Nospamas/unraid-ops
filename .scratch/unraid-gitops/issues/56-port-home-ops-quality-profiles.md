---
id: "56"
title: Port home-ops' quality profiles, and widen 46's boundary by one key
type: task
status: closed
description: >
  The 2160p policy 46 invented is replaced by the one home-ops researched
  against the TRaSH JSON — remux out, x265 in, SQP-1 for radarr. Cheap to swap
  because nothing is assigned to 46's profiles. Carries propers_and_repacks,
  which 46 had ruled out as media_management; the key is not naming and reaches
  no file on disk, so the boundary moves to name the key rather than the section.
touches:
  - stacks/recyclarr/conf/recyclarr.yml
  - docs/adding-a-service.md
  - .scratch/unraid-gitops/issues/46-add-recyclarr.md
---

# 56 — Port home-ops' quality profiles, and widen 46's boundary by one key

Resolved: 2026-08-22
Blocked by: —

## Question

rb asked for the recyclarr profiles from `~/home-ops` to be copied here. Both
repos run `recyclarr 8.7.1` on the same digest, so the config is portable
verbatim and this is not a translation job. Two things in it are not.

## Answer

### The profiles here were the weaker pair, and swapping them is nearly free

[46](46-add-recyclarr.md) picked `WEB-2160p` and `UHD Bluray + WEB` and admitted
it was **introducing** a policy rather than codifying one — the box held zero
custom formats. home-ops picked its pair by reading the TRaSH-Guides JSON, and
recorded the reasoning in `~/home-ops/.scratch/recyclarr/issues/01-profile-shape.md`:

| | 46 | now |
|---|---|---|
| sonarr | `WEB-2160p` | `WEB-2160p (Combined)` — WEB 2160p → WEB 1080p |
| radarr | `UHD Bluray + WEB` | `[SQP] SQP-1 (2160p)` — Bluray-2160p → WEB 2160p → 1080p → 720p |
| radarr `quality_definition` | `movie` | `sqp-uhd` |

Both exclude remux by design: `Remux-2160p` averages **61.3 GB** against ~27 GB
for a `Bluray-2160p` encode.

**Nothing is assigned to 46's profiles** — the map's own fog entry has all 187
series and 1736 movies still on `Any` — so this swaps a policy nobody is using
for a better one nobody is using. The cost that would normally make this
expensive, reassigning a library and queueing an upgrade backlog, is not owed.
That decision stays open and is unchanged by this ticket.

### Three score overrides, and why they are not fighting the guide

Copied as-is, with home-ops' reasoning:

- **x265 (HD) and x265 (no HDR/DV) softened −10000 → −100.** Both carry a
  *required, negated* `Not 2160p` spec and cannot fire on 4K at all; the guide's
  penalty targets 720p/1080p re-encodes. This only deprioritises x265 at the
  1080p fallback tier rather than rejecting it.
- **AV1 → −200.**
- **radarr `10bit` → 0**, overriding the `sqp-1-2160p` set's −10000. Deliberate
  in the guide and wrong here: real 4K HDR is inherently 10-bit, so leaving it
  would reject the encodes the profile exists to find.

Verified with `sync --preview` against the live radarr and sonarr before
committing: every trash_id resolves, and both profiles are found. The preview
logs `has conflicting scores in profile ...: -100 vs -10000 (first value wins)`
for each override, which reads like a defect and is not one — recyclarr resolves
a score as `assign_scores_to` → entry-level `score` → the profile's score set →
the guide, stopping at the first match, so the override is what lands. Worth
knowing because this Stack's `x-watch` says nothing watches the daily sync, and
the next person to open its log will meet those four lines with no context.

`delete_old_custom_formats: true` comes too — `reset_unmatched_scores` only
zeroes a score, it does not remove the format, and without this the four
`custom_format_groups` 46 added would linger in both apps unscored forever.

### The boundary moves by one key, and says so precisely

home-ops sets `media_management: propers_and_repacks: do_not_prefer`. 46 ruled
`media_management` **out** and wrote that in three places. rb's call is to carry
it and amend, which is right: 46's reasoning was never about the section, it was
about **naming** — the only half anyone had hand-tuned, and the only half whose
silent revert renames files on disk. `propers_and_repacks` renames nothing.

So the boundary is now stated as a key rather than a section, in both places 46
put it, because "media management is absent" is now false and a boundary that is
subtly wrong is worse than one that is coarse:

| owned by git | left in appdata |
|---|---|
| quality profiles | media naming |
| custom formats and their scores | the rest of media management |
| quality definitions (size limits) | indexers, root folders, download clients |
| `propers_and_repacks` | |

The third place 46 listed — the `config_files` entry in `komodo.toml` — needs no
change; it already carries `conf/recyclarr.yml` at `requires = "restart"`.

## Left over

The two profiles 46 created stay in sonarr and radarr as orphans. Recyclarr
writes quality profiles but never deletes them, and neither app is asked about
profiles it was not given.
