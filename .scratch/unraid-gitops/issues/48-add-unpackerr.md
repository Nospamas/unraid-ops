---
id: "48"
title: Add unpackerr
type: task
status: open
description: >
  Add unpackerr, which 40 ruled out on a false premise and 45 reinstated
  after finding an unimported rar set in the download share. home-ops already
  runs it, so the *arr wiring is a reference rather than a decision — but
  that tree is owned rseaforthb:1001, not 99:100.
touches: []
---

# 48 — Add unpackerr

Blocked by: —
Claimed by: claude session, 2026-08-08

## Question

`ghcr.io/unpackerr/unpackerr:0.15.2` — extracts archived releases so sonarr and
radarr can import them. [40](40-survey-complementary-services.md) ruled it out
because there is no usenet client on the box; [45](45-pick-from-the-survey.md)
found that premise wrong, because **torrent releases arrive rar'd too**.

The evidence is still sitting there:
`${MEDIA}/downloads/Nineteen.Eighty-Four.1954.1080p.BluRay.x264-ORBS/` is a
40-part rar set radarr could not import, and the extracted `.mkv` is loose in the
movies root, unrenamed and outside radarr's convention — a hand extraction after
a failed import. **Confirm that reading before building on it**: check radarr's
history for that release rather than inferring it from the filesystem, and if
radarr did import it some other way, this ticket's premise is as weak as 40's
was.

### home-ops already runs this

`~/home-ops/kubernetes/apps/media/unpackerr/app/helmrelease.yaml`, added
2026-07-08. It is a **reference for the wiring, not a template to copy** — that
is Kubernetes and this is compose, and the paths differ. What transfers:

- `UN_SONARR_0_URL` / `UN_RADARR_0_URL` plus `UN_*_API_KEY` per *arr — the keys
  are secrets here, so `just secret unpackerr`.
- `UN_*_PATHS_0` must be **the path as that *arr sees it**, not as unpackerr sees
  it. Here both are `${MEDIA}/downloads`; check what the *arr actually have
  configured rather than assuming the binds already agree.
- `UN_WEBSERVER_LISTEN_ADDR` gives it an HTTP listener — so unlike
  [46](46-add-recyclarr.md) this fronts and probes normally, and homepage ships
  an `unpackerr` widget. Turn it on; it is what makes the Stack visible.

### The trap this one carries

`${MEDIA}/downloads` and its contents are owned **`rseaforthb:1001`**, not the
`99:100` every Stack runs as ([09](09-unify-uid-gid.md),
[20](20-chown-to-99-100.md)). Unpackerr writes extracted files into that tree.
Work out what it can and cannot do there **before** deploying — the failure mode
is a Stack that starts clean, reports green, and silently fails every extraction.
Whether the fix is a chown of that tree or something narrower is this ticket's to
decide, and a chown of a 40G+ share is a gated change, not a side effect.

### Then the routine

Per [docs/adding-a-service.md](../../../docs/adding-a-service.md), **new**
flavour. Not a linuxserver image — see the PUID trap in that file's Traps
section. `caddy.import: internal`, add the Stack to `BatchDeployStackIfChanged`
in [komodo/procedures.toml](../../../komodo/procedures.toml), then `just
reconcile`.

**Verify it extracts something**, not that it started. A green reconcile is not a
running service, and this one is inert until a packed release arrives.

## Hand-offs

To be recorded on resolution.
