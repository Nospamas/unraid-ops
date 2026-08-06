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
- [35 — Add tautulli, and backfill plex's watch
  history](issues/35-add-tautulli.md) — tautulli runs from git, probed on
  `/status` rather than `/`, with no plex appdata bind of any kind: **the
  backfill does not exist**. Tautulli cannot read plex's database, upstream
  closed that `wont-fix`, so the question's three-way choice was moot, and rb
  declined the one route left: a converter that invents the watch durations plex
  never recorded.

## Not yet specified

- **Whether git should own tautulli's and bazarr's own settings.**
  [CONTEXT.md](../../CONTEXT.md) draws the line at appdata and makes homepage the
  sole exception. Both new services keep their tuning — language profiles,
  scoring, provider lists — in a SQLite database a rebuild loses. Tautulli is
  now on the box and splits it: a text `config.ini` beside `tautulli.db`, and
  only the first is the shape homepage's exception was carved for [35]. Sharp
  only once there is tuning worth losing.
- **Whether `home.rbrb.in` retires in favour of the apex.**
  [37](issues/37-bare-domain-to-homepage.md) makes the apex a redirect on purpose,
  keeping one canonical name. If the bare domain turns out to be the one rb
  actually types, the redirect points the wrong way.

## Out of scope

- **Tautulli's notification agents.**
  [29](issues/29-alerting-on-failed-reconcile.md) already probes plex end to end,
  so plex-is-up is answered, and playback pings would dilute the topic that
  carries real failures. A separate ntfy topic would be a separate decision.
- **An HTTP→HTTPS redirect.** Caddy already does it, verified rather than
  assumed, so there is nothing to build.
