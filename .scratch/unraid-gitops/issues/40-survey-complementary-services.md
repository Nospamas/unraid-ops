# 40 — Survey what else commonly runs alongside this stack

Type: research
Status: open
Blocked by: —

## Question

Before the dashboard is reworked, settle what is *meant* to be on it. This box
runs plex, sonarr, radarr, prowlarr, prowlarr's indexers, qbittorrent behind
gluetun, calibre, lazylibrarian, and — after [35](35-add-tautulli.md) and
[36](36-add-bazarr.md) — tautulli and bazarr. Find the gaps worth filling.

Survey what people running this shape of stack commonly add, and for each
candidate record:

- **what it does that nothing here already does** — the bar is a real gap, not a
  nicer version of something running
- whether it is maintained, and what its image looks like (a pinnable
  `version@digest`, per [12](12-image-update-strategy.md) — **nothing is built on
  the box**)
- what it would need from this box: a media bind, a *arr API key, a host port, a
  secret, a device
- whether homepage ships a widget for it — relevant because
  [39](39-rework-homepage-dashboard.md) is next

Obvious ground to cover: request/discovery front-ends, a subtitle or metadata
tool bazarr does not already cover, music and audiobook management, download
client alternatives, dashboards and stats beyond tautulli, and the maintenance
utilities (orphan cleanup, library repair) that the *arr do not do themselves.
That list is a starting point, not a scope.

**This ticket recommends; it does not install.** Anything worth having becomes
its own ticket, which is also what makes it appear on the dashboard. Write the
findings to `../assets/40-complementary-services.md` and link it here.

Two standing constraints that rule candidates out cheaply, and are worth
applying while reading rather than after:

- **Nothing faces the internet without `x-published`**, and the trigger for
  adding authentication in front of the services is a *second* service with an
  external route ([31](31-plex-own-internet-exposure.md)). A candidate whose
  whole point is inviting outside users drags that decision forward with it — say
  so rather than quietly proposing it.
- **Every new Stack is one more thing Renovate tracks and gatus probes.** Cheap,
  but not free.

## Hand-offs

None — this is reading, and the picking is a conversation on resolution.
