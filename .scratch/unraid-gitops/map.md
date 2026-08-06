# Map 02: Metrics, subtitles, and a front door worth opening

## Destination

Tautulli and bazarr running from git and wired into plex and the *arr; a
`home.rbrb.in` that rb opens by choice rather than bookmarks around; and standing
context that lives in [CLAUDE.md](../../CLAUDE.md), [CONTEXT.md](../../CONTEXT.md)
and the closed issues, so this map stays an index and never grows a second copy
of the rules.

## Notes

**The standing rules are not here.** [CLAUDE.md](../../CLAUDE.md) is auto-loaded
and points at [CONTEXT.md](../../CONTEXT.md) for vocabulary,
[docs/conventions.md](../../docs/conventions.md) for the rules and
[docs/adding-a-service.md](../../docs/adding-a-service.md) for the routine. Read
the section, not the file. This map indexes decisions; it does not restate them,
and it does not become a fifth doc.

**Execution override**: this map carries execution, not just decisions. The
destination is running services, not a spec.

**Map 01 is archived** at [map-01-foundation.md](map-01-foundation.md), its
destination reached. Until [33](issues/33-migrate-map-01-standing-content.md)
closes it is still the fullest account of the two networks, box access and
Komodo's quirks — read it rather than re-deriving them.

**Questions that outlive a map** go to [open-questions.md](open-questions.md),
stood up by [33](issues/33-migrate-map-01-standing-content.md). Fog belonging to
a future effort is deferred there rather than carried into the next map's fog,
where it would rot.

**Issues carry frontmatter** — `id`, `title`, `type`, `status`, `description`,
`touches` ([34](issues/34-issue-frontmatter.md)). `description` is the gist, so
an issue can be triaged without opening it; `touches` inverts the index, so a
path greps back to the ticket that explains it.

**Claim a ticket before working it.** Sessions run in parallel — the frontier is
six wide — and this tracker has no assignee field, so add one to the issue and
**commit it first**, before any other work:

```
Claimed by: <session or human>, <date>
```

An open ticket with no `Claimed by:` line is unclaimed. Clear the line if the
session ends without resolving it, or the ticket looks taken and is not.

**Skills**: `/grilling` and `/domain-modeling` for decisions, `/research` for AFK
reading, `/prototype` where a rough artifact settles an argument faster than
discussion.

## Decisions so far

<!-- one line per closed ticket — the ticket holds the detail -->

## Not yet specified

- **Whether git should own tautulli's and bazarr's own settings.**
  [CONTEXT.md](../../CONTEXT.md) draws the line at appdata and makes homepage the
  sole exception. Both new services keep their tuning — language profiles,
  scoring, provider lists — in a SQLite database a rebuild loses. Sharp only once
  there is tuning worth losing.
- **Whether `home.rbrb.in` retires in favour of the apex.**
  [37](issues/37-bare-domain-to-homepage.md) makes the apex a redirect on purpose,
  keeping one canonical name. If the bare domain turns out to be the one rb
  actually types, the redirect points the wrong way.
- **Whether [adding-a-service.md](../../docs/adding-a-service.md) gains a
  gatus-probe step.** The routine never says to add one — only the Traps section
  mentions it, which is how a new service lands unmonitored.
  [35](issues/35-add-tautulli.md) or [36](issues/36-add-bazarr.md) may settle it
  in passing.

## Out of scope

- **Tautulli's notification agents.**
  [29](issues/29-alerting-on-failed-reconcile.md) already probes plex end to end,
  so plex-is-up is answered, and playback pings would dilute the topic that
  carries real failures. A separate ntfy topic would be a separate decision.
- **An HTTP→HTTPS redirect.** Caddy already does it, verified rather than
  assumed, so there is nothing to build.
