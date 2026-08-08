# Map 02: Metrics, subtitles, and a front door worth opening

## Destination

Tautulli and bazarr running from git and wired into plex and the *arr; a
`home.rbrb.in` that rb opens by choice rather than bookmarks around; and standing
context that lives in [CLAUDE.md](../../CLAUDE.md), [CONTEXT.md](../../CONTEXT.md)
and the closed issues, so this map stays an index and never grows a second copy
of the rules.

## Notes

**How this tracker works** is [README.md](README.md) — what a map may hold, the
issue frontmatter, and **claim a ticket before working it**, which matters
because the frontier is wide and sessions run in parallel. Read it before editing
this file.

**The standing rules are not here.** [CLAUDE.md](../../CLAUDE.md) is auto-loaded
and points at [CONTEXT.md](../../CONTEXT.md) for vocabulary,
[docs/conventions.md](../../docs/conventions.md) for the rules and
[docs/adding-a-service.md](../../docs/adding-a-service.md) for the routine. Read
the section, not the file.

**Execution override**: this map carries execution, not just decisions. The
destination is running services, not a spec.

**Map 01 is archived** at [map-01-foundation.md](map-01-foundation.md), in place
rather than gutted ([33](issues/33-migrate-map-01-standing-content.md)) — so it
is still the fullest account of the two networks, box access, and the questions
this repo has ruled against. Read it rather than re-deriving them.

**Questions that outlive a map** go to [open-questions.md](open-questions.md),
deferred rather than declined. Fog belonging to a future effort is parked there
rather than carried into the next map's fog, where it would rot.

**Skills**: `/grilling` and `/domain-modeling` for decisions, `/research` for AFK
reading, `/prototype` where a rough artifact settles an argument faster than
discussion.

## Decisions so far

<!-- one line per closed ticket — the ticket holds the detail -->

- [25 — Retire Portainer](issues/25-retire-portainer.md) — gone entirely, appdata
  included: the rollback it was held for was already dead, and the WireGuard key
  now has exactly one plaintext copy on the box, the one the Stack needs.
- [33 — Migrate map 01's standing content, and stand up the open-questions
  register](issues/33-migrate-map-01-standing-content.md) — **an archive is
  cheaper than a migration**: map 01 stays readable, only the two things a
  session would get wrong unprompted moved into the docs, and the four rules
  about the tracker itself that had been squatting in map Notes now live in
  [README.md](README.md).
- [34 — Retrofit frontmatter onto the closed
  issues](issues/34-issue-frontmatter.md) — all 42 issues carry
  `id`/`title`/`type`/`status`/`description`/`touches`, so a set can be filtered
  without reading and a repo path greps back to the issue that explains it. The
  body header keeps only what the schema deliberately refuses — the blocking
  edge, the claim, the date and the asset.
- [43 — Probe home-ops from tower, closing the box-down
  gap](issues/43-cross-site-probes-to-home-ops.md) — three probes at home-ops
  alerting to tower's own ntfy, with no cross-site credential. The names needed
  two narrow CoreDNS zones rather than a blanket forward, because `.` must keep
  answering REFUSED. Closes the last half of [29].
- [35 — Add tautulli, and backfill plex's watch
  history](issues/35-add-tautulli.md) — tautulli runs from git, probed on
  `/status` rather than `/`, with no plex appdata bind of any kind: **the
  backfill does not exist**. Tautulli cannot read plex's database, upstream
  closed that `wont-fix`, so the question's three-way choice was moot, and rb
  declined the one route left: a converter that invents the watch durations plex
  never recorded.
- [36 — Add bazarr](issues/36-add-bazarr.md) — bazarr runs from git, media binds
  mirroring the *arr's, and ships inert as intended. The routine held: its one
  decision was the probe endpoint, and `/` failed 35's test — it is a 200 only
  while bazarr's UI auth is off. `/api/system/ping` is the API's one keyless
  route and does not move.
- [37 — Point the bare domain at
  homepage](issues/37-bare-domain-to-homepage.md) — `rbrb.in` 308s to
  `home.rbrb.in` from its own block and its own cert, guard imported **inside a
  `route`**: Caddy sorts `redir` ahead of `respond`, so the obvious spelling
  would have 308'd the whole internet while reading as guarded. Nothing
  outstanding: the Cloudflare A record the ticket expected to hand off was
  already there.

- [38 — Close the homepage tile gaps](issues/38-homepage-tile-gaps.md) — all four
  tiles are on the dashboard. Only gatus held a decision: it is host-networked,
  so it has no name on `shared`, and it dials `host.docker.internal` — the box's
  LAN IP is a DHCP lease git cannot own, and `status.rbrb.in` would be 403'd by
  the guard for arriving from a bridge.

- [40 — Survey what else commonly runs alongside this
  stack](issues/40-survey-complementary-services.md) — five candidates clear the
  gap bar — cleanuparr, maintainerr, recyclarr, seerr and audiobookshelf — and
  each carries a decision rather than an install: seerr drags the auth question
  forward, maintainerr wants delete rights on the media share, recyclarr claims a
  named slice of the *arr's settings. The picking is rb's, in
  [45](issues/45-pick-from-the-survey.md). **`revisitable`, due 2026-09-07** —
  the reading holds, the specifics rot.

- [45 — Pick what the survey found, if
  anything](issues/45-pick-from-the-survey.md) — recyclarr and audiobookshelf,
  plus unpackerr, which rb remembered from home-ops and which 40 had ruled out on
  a false premise. **Checking the media share instead of reasoning about it
  corrected three of the survey's claims**: there are no audiobooks, there is
  550G of music, and a rar'd release is sitting unimported in the download share.

- [49 — Renovate has never offered a linuxserver
  update](issues/49-renovate-never-saw-linuxserver.md) — not the 429s: Renovate's
  default `docker` versioning requires a candidate's suffix be identical, and
  `-lsNNN` increments every build, so the only compatible tag was the one already
  pinned. Fixed with `regex:` versioning and a `registryAliases` to ghcr.io, the
  name Renovate recognises; lazylibrarian cannot be versioned at all and is off.

- [39 — Rework the homepage
  dashboard](issues/39-rework-homepage-dashboard.md) — the page is a launcher,
  not a status board, so gatus stays a tile rather than a header summary. Groups
  cut by use vs machinery, three columns, and a header row of
  resources/search/weather/clock whose disk figure is real for the first time:
  nothing was ever mounted, so it had been reading the container's own overlay.

- [41 — Dispose of the five orphan Unraid
  templates](issues/41-orphan-unraid-templates.md) — all ten files gone. The
  record was redundant with git down to lazylibrarian's `DOCKER_MODS`, and it was
  never a rollback — but the ticket's "hold no secrets" was wrong:
  `my-calibre.xml` and its `.bak-19` held the live GUI password cleartext, and it
  is reused. The routine never disposed of a template, which is why five were
  sitting there; step 8b does now.

- [52 — One password guards qbittorrent, calibre and
  lazylibrarian](issues/52-one-password-across-four-services.md) — the reuse is
  deliberate, convenience over security for internal-only web interfaces, and
  [19]'s ruling stands. The blast radius is also narrower than it looked:
  qbittorrent whitelists the whole of `shared`, so the *arr's copies of the
  password are never sent, and rotating it would not change qbittorrent's
  exposure at all.

- [42 — Make the array come back on its own after a
  reboot](issues/42-array-auto-start.md) — the array starts itself, and
  `startArray` is recorded as an **assertion** — a named flash key `host-check`
  reads and never applies — not a second snapshot. It also gave [26]'s admission
  test a third limb: *or leave the box needing a human to recover from something
  it used to recover from alone*. The limb is about silence, not severity:
  `DOCKER_ENABLED` fails it because `just bootstrap` dies loudly without it.

- [44 — Give the routine its gatus-probe
  step](issues/44-probe-step-in-the-routine.md) — step 7b, plus
  [check-probes.sh](../../scripts/check-probes.sh): a step alone would have been
  the same prose that already failed, because **a missing probe is the one fault
  with no signature**. The step carries the judgement, the check carries the
  fact; ntfy's browser door turned out to be the gap — home-ops watches the
  other door — and got probed rather than excepted.

- [46 — Add recyclarr](issues/46-add-recyclarr.md) — recyclarr runs from git and
  owns quality profiles, custom formats and quality definitions; **naming stays
  hand-set**, because it is the only half anyone had tuned and a silent revert
  there reaches files on disk. The ticket's premise was wrong — both *arr held
  zero custom formats, so this introduced a 2160p policy rather than codifying
  one, and it governs nothing until the library is moved onto it. First headless
  Stack: nothing watches it, `x-watch` says so, and that is argued per Stack
  rather than inherited.

## Not yet specified

- **Whether git should own tautulli's and bazarr's own settings.** Not a
  permission question — [CONTEXT.md](../../CONTEXT.md) has been corrected to say
  reconciled-or-appdata is a per-service choice, and homepage was never an
  exception to a rule. It is a **worth-it** question. Both services keep their
  tuning — language profiles,
  scoring, provider lists — in a SQLite database a rebuild loses. Both are now on
  the box and both split it the same way: a text config beside a `.db`,
  `config.ini`/`tautulli.db` [35] and `config/config.yaml`/`db/bazarr.db` [36],
  and only the text half is worth git owning. Sharp once there is tuning worth
  losing — bazarr has none today and will the moment
  rb sets its language profiles. [38] adds a first concrete cost: homepage now
  holds a sops copy of each service's API key, and a rebuild rotates both —
  [39](issues/39-rework-homepage-dashboard.md) raised that from four keys to six
  by keeping every widget rather than culling.
- **Whether the 550G of music gets managed or served.**
  [45](issues/45-pick-from-the-survey.md) found `music-rb` and `music-reg` on the
  share — unindexed, unplayed, and organised differently from each other.
  Navidrome would serve what is already there; Lidarr would acquire more against
  a metadata server that has been unreliable all year. Not picked, and the two
  halves are not the same decision.
- **Whether `home.rbrb.in` retires in favour of the apex.**
  [37](issues/37-bare-domain-to-homepage.md) made the apex a redirect on purpose,
  keeping one canonical name. If the bare domain turns out to be the one rb
  actually types, the redirect points the wrong way.

- **Which library items get the 2160p policy, and when.**
  [46](issues/46-add-recyclarr.md) created the profiles; nothing uses them — 187
  series and 1736 movies are all still on `Any`. Not a chore: the array has 23T
  free against 1736 movies averaging 14G, so moving them wholesale queues an
  upgrade backlog that does not fit. Sharp once someone decides whether this is
  a policy for **new** acquisitions only or a backfill with a budget.

- **Whether a watchdog sits beside Renovate.**
  [49](issues/49-renovate-never-saw-linuxserver.md) went undetected for months
  because Renovate going quiet looks exactly like nothing being released — no
  error, no PR, no dashboard entry. Diun notifies on new build tags and speaks
  ntfy natively, so the plumbing from [29] is already there. It cannot replace
  Renovate — it resolves no digest and writes no file, which is [12]'s declined
  `poll_for_updates` — but beside it, it catches the silence. Three things it
  would have to settle: where it gets its image list (`dockerproxy` rather than
  the raw socket), how `watchRepo` avoids the rate limit the box already hit at
  [35], and that its `includeTags` regex mirrors Renovate's versioning rule
  without drifting from it.

## Out of scope

- **Tautulli's notification agents.**
  [29](issues/29-alerting-on-failed-reconcile.md) already probes plex end to end,
  so plex-is-up is answered, and playback pings would dilute the topic that
  carries real failures. A separate ntfy topic would be a separate decision.
- **An HTTP→HTTPS redirect.** Caddy already does it, verified rather than
  assumed, so there is nothing to build.
