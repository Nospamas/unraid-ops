# 07 — Decide the repo layout and per-service conventions

Type: grilling
Status: open
Blocked by: 02, 03

## Question

What is the atom of this repo, and what does adding a service look like?

home-ops answers this with an **App** — one directory per workload, a `ks.yaml`
plus an `app/` dir, named by the `&app` anchor. This repo needs its own answer,
in its own vocabulary. Run `/domain-modeling` alongside the grilling and write
the result to `CONTEXT.md`.

Settle:

- **Directory shape** — one compose file per service, or one stack grouping the
  media services? The reconcile mechanism from ticket 02 may force this.
- **The unit's name** — "service", "stack", "app" — and what it owns.
- **Shared configuration** — the PUID/PGID/TZ trio, appdata root, and the media
  library paths appear in every service. Where do they live so they are stated
  once? Compose `extends`, a YAML anchor file, or a `.env` at the root.
- **What appdata paths look like** in git, given the array paths recorded in
  ticket 01.
- **Where secrets are referenced**, following ticket 03's mechanism.
- **What "adding a service" is**, written as a short checklist — this is what
  makes the *arr migrations repetitive work rather than fresh decisions.

The answer is the layout, the vocabulary, and the add-a-service checklist.
