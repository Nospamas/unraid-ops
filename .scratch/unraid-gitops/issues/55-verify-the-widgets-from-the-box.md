---
id: "55"
title: Sweep homepage's widgets from the box, in the routine
type: grilling
status: open
description: >
  50 found the check this Stack never had — homepage proxies every widget call
  server-side, so a curl per service from the box says whether the tile has
  data. Three silent failures in a row argue for it; whether it earns a routine
  step or stays a recipe is the question.
touches:
  - scripts/check-probes.sh
  - docs/adding-a-service.md
  - stacks/homepage/config/services.yaml
---

# 55 — Sweep homepage's widgets from the box, in the routine

Blocked by: —
See also: [44](44-probe-step-in-the-routine.md), which settled the same argument
for gatus probes and is the model to copy or to consciously depart from.

## Question

homepage has failed silently three times — [38](38-homepage-tile-gaps.md)'s keys
were never added, [39](39-rework-homepage-dashboard.md)'s CSS selector matched
nothing, and [50](50-homepage-secrets-and-verify.md)'s secret file was untracked
so no deploy ran. Every one looked like a green reconcile and a correct repo,
and each was found weeks later by someone reading a file.

50 found the check. Widget calls go through homepage's **own server-side proxy**,
so a tile's data is reachable without a browser:

```sh
curl -H 'Host: home.rbrb.in' \
  'http://<homepage-ip>:3000/api/services/proxy?group=<group>&service=<service>&endpoint=<endpoint>'
```

A sweep over `services.yaml` catches two of the three shapes. Decide:

- **Where it lives.** [44](44-probe-step-in-the-routine.md) put the judgement in
  a routine step and the fact in `check-probes.sh`. This one has no judgement to
  carry — a widget either answers or it does not — which argues for a recipe run
  on demand rather than a step in a routine that only fires when a *service* is
  added. The failures were all homepage edits, not new services.
- **It cannot be `just lint`.** It issues requests and needs the box, which is
  the line `check-probes.sh` already draws.
- **The endpoint names are undocumented.** They are the second argument to
  `useWidgetAPI` in `/app/src/widgets/<type>/component.jsx` *inside the image*,
  and a version bump can move them. A hardcoded table in the repo drifts
  silently — the exact failure mode being fixed. Reading them out of the running
  container each sweep does not, and is a bind away.
- **How much a pass proves.** A widget answering means the key, the network name
  and the service are all good. It does not mean the tile *renders* — 39's CSS
  bug is invisible to this — so the step must not read as "the page is verified".
- **The information widgets are a separate surface**, on
  `/api/widgets/<type>`. `resources?type=disk&target=/mnt/user` is worth having:
  it proves the disk binds took, which 39 could only confirm by eye. `openmeteo`
  resists — the client passes the coordinates as query params, so a sweep would
  have to read the substituted config first.

## Hand-offs

To be recorded on resolution.
