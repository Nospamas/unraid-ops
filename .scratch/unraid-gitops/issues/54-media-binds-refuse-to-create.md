---
id: "54"
title: Decide whether every media bind refuses to create its host path
type: grilling
status: open
description: >
  47 gave audiobookshelf's two media binds `create_host_path: false`, so a
  missing tree fails the deploy instead of arriving as an empty root:root one.
  Every other media bind in the repo still creates silently. The question is
  whether that is a rule, and whether the lint says so.
touches:
  - docs/conventions.md
  - scripts/check-probes.sh
---

# 54 — Decide whether every media bind refuses to create its host path

Blocked by: —

## Question

Docker creates a missing bind source `root:root` by default. For a media tree
that is always the wrong answer — the container runs 99:100 and cannot write to
it — and it is **silent**: the Stack deploys green, the container starts, and
the library is simply empty. [47](47-add-audiobookshelf.md) hit it and used
compose's long syntax to refuse:

```yaml
- type: bind
  source: ${MEDIA}/audiobooks
  target: /audiobooks
  bind:
    create_host_path: false
```

`pre_deploy` cannot cover this the way it covers appdata. **Periphery binds
`/mnt/user/appdata` and nothing else** [29], so a `mkdir` under `${MEDIA}`
succeeds inside Periphery and changes nothing on the host — the one shape this
map keeps getting bitten by.

### What has to be settled

- **Is it a rule or was it 47's local call?** plex, sonarr, radarr, bazarr,
  download and audiobookshelf hold media binds between them. Retrofitting is
  mechanical, but it converts a class of silent wrong-answer into a class of
  failed deploy, and a failed deploy at 3am is a different cost from an empty
  library.
- **Does anything enforce it?** This is [53](53-lint-the-headless-statement.md)'s
  shape exactly: a cheap file-only check, `${MEDIA}` binds only, that would have
  to retrofit existing Stacks. Both tickets are arguing about the same thing —
  whether a convention nothing checks is a convention — so whichever lands
  second should read the first.
- **Does appdata want it too?** No, and the reason should be written down rather
  than assumed: `pre_deploy` genuinely does create appdata paths, so refusing
  there would break the mechanism that works.
- **Is the short form enough?** `- ${MEDIA}/tv:/tv:ro` cannot express this;
  taking the rule means every media bind grows into four lines, which is a real
  legibility cost against a real silent failure.
