---
id: "45"
title: Pick what the survey found, if anything
type: grilling
status: closed
description: >
  Recyclarr and audiobookshelf, plus unpackerr — which rb remembered from
  home-ops and which 40 had ruled out on a false premise. Checking the media
  share instead of reasoning about it corrected three of the survey's claims:
  there are no audiobooks, there is 550G of music, and a rar'd release is
  sitting unimported in the download share.
touches: []
---

# 45 — Pick what the survey found, if anything

Resolved: 2026-08-07
Blocked by: —

## Question

[40](40-survey-complementary-services.md) surveyed and deliberately did not pick.
Pick. **Nothing is the allowed answer** — every new Stack is one more thing
Renovate tracks and gatus probes.

The five that cleared its bar, and the decision each one arrives holding:

- **Cleanuparr** — does rb care that a stalled download sits in a queue forever?
- **Maintainerr** — is anything on the media share worth deleting automatically,
  by rules that live outside git?
- **Recyclarr** — does the quality-profile drift hurt enough to reconcile a slice
  of the service settings [CONTEXT.md](../../../CONTEXT.md) says are not
  reconciled?
- **Seerr** — **does anyone but rb ask for media?** If yes it is published, and
  the authentication question in [open-questions.md](../open-questions.md) comes
  with it. If no, it does not clear the bar.
- **Audiobookshelf** — does rb have audiobooks?

The last two are questions about rb, not about the box; the first three are about
this repo's own lines. Read the asset
([40-complementary-services.md](../assets/40-complementary-services.md)) before
the conversation, not during it.

Whatever is picked becomes its own ticket per
[docs/adding-a-service.md](../../../docs/adding-a-service.md), which is also what
puts it on the dashboard — hence this blocks
[39](39-rework-homepage-dashboard.md), which needs to know what it is laying out.
Order matters if more than one is picked: 39 should not wait behind all of them.

## Answer

**Recyclarr and audiobookshelf** — [46](46-add-recyclarr.md) and
[47](47-add-audiobookshelf.md). **Plus unpackerr**, which rb remembered running
in home-ops and which [40](40-survey-complementary-services.md) had ruled out —
[48](48-add-unpackerr.md).

Not picked, and not declined: cleanuparr, maintainerr and seerr. They keep their
entries in the asset; nobody argued against them, the conversation simply did not
reach them.

### The survey was wrong three times, and the box said so

Every correction came from listing `/mnt/user/Media` rather than reasoning about
it. **That is the lesson worth keeping**: 40 was AFK research and answered every
question about the box from the repo, which describes what is *defined*, not what
is *there*.

- **Unpackerr was ruled out on a false premise.** "Nothing here arrives as split
  archives — no usenet client on the box" ignored that torrent releases are
  rar'd too. `downloads/Nineteen.Eighty-Four.1954.1080p.BluRay.x264-ORBS/` is a
  40-part rar set, and the extracted `.mkv` is sitting loose in the movies root,
  unrenamed and outside radarr's convention — the signature of a hand extraction
  after a failed import.
- **"There is no music here at all" was 550G wrong.** `music-rb` is 440G of 1025
  loose files; `music-reg` is 110G in 1104 artist directories. Unmanaged and
  unserved. This reverses the Lidarr+Navidrome entry — **Navidrome is the
  valuable half**, because the library already exists and nothing plays it, while
  Lidarr's job is acquisition against a metadata server that has been unreliable
  all year. Not picked here, but it is a different proposition from the one 40
  described, and the asset says so now.
- **Audiobookshelf has no audiobooks to serve.** `books/` is calibre's library —
  514M, three epubs, a `metadata.db`, zero `.m4b`, zero `.mp3`. `podcasts/` is
  6.2G of one series. It was picked anyway, so [47](47-add-audiobookshelf.md)
  builds it as **a podcast server that is ready for audiobooks** and says so
  rather than pretending the tile will have books on it.

### And once more, about a rule that was never a rule

[40](40-survey-complementary-services.md) called recyclarr a contradiction of
[CONTEXT.md](../../../CONTEXT.md)'s line that service settings are not
reconciled, and this ticket's own question repeated it. **rb's correction: that
was never a prohibition** — it was a glossary entry from
[07](07-repo-layout-and-conventions.md) describing where settings live by
default, and either home is fine. Homepage was not an exception to a rule, it was
the first service to take the other option.

CONTEXT.md now says so: reconciled-or-appdata is a per-service choice, and what
is fixed is only that the choice is stated. [46](46-add-recyclarr.md) lost a
decision because of it, and the fog about tautulli's and bazarr's settings
stopped being a permission question.

**Both of this session's errors are the same error** — treating the repo's
description of what *is* as a ruling about what *may be*.

### One more thing the box said

`downloads/` and its contents are owned by `rseaforthb:1001`, not `99:100`
([09](09-unify-uid-gid.md), [20](20-chown-to-99-100.md)). Not this
ticket's problem, but **unpackerr writes into that tree**, so
[48](48-add-unpackerr.md) inherits it.

## Hand-offs

None. The three tickets are the output.
