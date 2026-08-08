---
id: "48"
title: Add unpackerr
type: task
status: closed
description: >
  unpackerr runs from git watching ${MEDIA}/downloads, not the *arr queues —
  the *arr have 39 grabs and zero failures between them, and neither rar'd
  release was ever theirs. It also found that docker's 022 umask silently
  masks any UN_DIR_MODE, which is how [19]'s failure got back in.
touches:
  - stacks/unpackerr/compose.yaml
  - stacks/unpackerr/komodo.toml
  - stacks/unpackerr/secrets.sops.env
  - stacks/gatus/conf/config.yaml
  - stacks/homepage/config/services.yaml
  - komodo/procedures.toml
  - docs/adding-a-service.md
---

# 48 — Add unpackerr

Resolved: 2026-08-08
Blocked by: —

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

## Resolution

unpackerr runs from git, **watching `${MEDIA}/downloads`** — the half of it this
ticket did not ask for. Probed on `/metrics`, tiled under **Transport**, and it
has extracted the release [45] found.

### The premise did not survive the check this ticket demanded

The ticket said to read radarr's history rather than infer from the filesystem.
Doing so falsified more than it was aimed at:

- **Radarr has never heard of the release.** No *Nineteen Eighty-Four* among its
  1736 movies, and no *Portlandia* among sonarr's 187 series.
- **Neither *arr is an acquisition path.** radarr: **3 grabs, ever**. sonarr:
  **36**, almost all one show on one day in November. Both: **zero**
  `downloadFailed`, **zero** `downloadIgnored`. There is no failed-import
  history to fix, because there are barely any imports.
- **qbittorrent holds 14 torrents, 13 with no category at all** — the signature
  of a hand-added torrent rather than an *arr grab.
- **45 was wrong about the hand extraction too.** It reported the `.mkv` loose in
  the movies root; there is no such file anywhere in the library. The release had
  simply sat rar'd since 2026-07-20, unwatched.

So the wiring this ticket specified — home-ops' shape, polling the *arr queues —
would have deployed a daemon that **correctly did nothing, forever**. That is the
outcome [40] and [45] each reached from the opposite direction, and it took the
third look to see that both were reasoning about the wrong half of the tool.

### rb picked the watched folder

`[[folder]]` extracts whatever lands in the path, independent of any *arr, which
is what matches how this box actually acquires. The *arr blocks ride along for
the rare grab and cost two env vars and a secret. rb declined watching
`${MEDIA}/movies` as well, where two loose `.rar` still sit — that is the library,
not a staging area, and a wider blast radius for two files.

### The trap the ticket feared was the wrong trap

`${MEDIA}/downloads` is `nobody:users` 775; 23 of its release directories predate
the uid unification and are `rseaforthb:**1001**` — a gid with **no group entry
at all**, so 99:100 gets `r-x` and nothing else. That never bites, because
`move_back` stays off: output goes to a **sibling** `<release>_unpackerred/` in
the downloads root, which 99:100 owns, and the release directory is only ever
read. **No chown of a 40G share, gated or otherwise.** Nothing is deleted either
— `delete_after: 0`, both delete switches off — because the archives are what
qbittorrent seeds from.

### The trap that was real: docker's umask beats any mode setting

unpackerr **prints** its umask at startup and never sets it, so it inherits
docker's `022`. That masks `UN_DIR_MODE: 0775` to 0755 and `UN_FILE_MODE: 0664`
to 0644 — and the first extraction landed a 7.8G mkv in a directory rb could not
move it out of, which is exactly the state [19] took the box off `chmod -R 777`
to escape. **No mode value can escape a umask**; the umask has to change. The
image ships a shell, so the entrypoint is
`["/bin/sh", "-c", "umask 002; exec /unpackerr \"$$@\"", "--"]` and the startup
log now reads `Umask: 2`. Re-verified end to end with a throwaway zip: 775 dirs,
664 files, `nobody:users`. The routine's standing claim that `UMASK` is merely
*inert* for a non-linuxserver image now carries the case where it is *wrong*.

Two smaller ones, both in the routine now:

- **`UN_WEBSERVER_LISTEN_ADDR` alone starts nothing.** `Enabled()` is
  `Metrics && ListenAddr != ""`, so without `UN_WEBSERVER_METRICS` it logs
  `Webserver Disabled` while the container sits `Up` — a green reconcile with no
  listener, caught by reading the log rather than the reconcile.
- **The watcher baselines what is already there.** A release sitting in the share
  before the Stack existed fires no event and is never extracted; `touch` the
  directory to trigger one. This is why "verify it extracts something" needed a
  deliberate nudge rather than a wait.

### The probe

`/` is a 200 that proves nothing again — the handler is
`fmt.Fprint(w, "Welcome!\n")`, a literal that cannot fail while the process
lives. `/metrics` is the same listener reporting on itself and its body names
both *arr it polls, so a broken API key or a renamed container fails the probe
instead of hiding behind a 200.

Homepage gets an **href-only tile**: the ticket claimed homepage ships an
`unpackerr` widget and it does not — there is no such type among its 166.
`unpackerr.png`, because dashboard-icons has no svg for it and an unresolved name
renders blank.

### Verified

`Up` and doing its job, not merely reconciled: **7.8GB extracted from a 40-part
rar set in 3m39s**, originals untouched, output `775`/`664` after the umask fix
(the first run's output was repaired by hand to match). gatus green on both
conditions, tile renders, `just lint` and `just verify-secrets` pass.

## Hand-offs

- **File `nineteen.eighty-four.1954.1080p.bluray.x264-orbs.mkv`** out of
  `downloads/Nineteen.Eighty-Four.1954.1080p.BluRay.x264-ORBS_unpackerred/` —
  unpackerr extracts, it never imports, and radarr does not track this film. Its
  mtime reads **2098-01-01** from the rar header, which will sort it oddly.
- **Extract or delete the two loose `.rar` in the movies root** —
  `sheryl.2022.2160p.web.h265-bigdoc.rar` and
  `mr.bachmann.and.his.class.2021.1080p.web.h264-skyfire.rar`. Out of unpackerr's
  watch path by rb's own choice, so nothing will ever touch them.
