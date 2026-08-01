# 10 — Publish the repo to a remote the box can reach

Type: task (HITL)
Status: open

## Question

Graduated out of the fog by [02](02-choose-reconcile-mechanism.md), which turned
this from a deferred nicety into a **hard prerequisite**: Komodo reconciles by
cloning the repo onto the box. Until a remote exists that the box can reach,
there is nothing for it to reconcile *from*, so
[08 — Deploy homepage from the repo](08-deploy-homepage.md) cannot prove
anything.

**Komodo clones over HTTPS and does not support SSH clone.** That constrains the
answer: whatever the remote is, it must serve HTTPS to the box, and Komodo needs
an HTTPS credential (a git account with a token) for a private repo.

Settle:

- **Which remote.** GitHub is the assumed default and the map's fog named it,
  but say so deliberately — a self-hosted forge on the box itself is a
  circular dependency (Komodo would clone from a container Komodo deploys), so
  it is probably ruled out here rather than considered later.
- **Public or private.** This repo will hold the box's whole container topology
  — LAN addresses, tailscale hostname, port mappings, appdata paths, and
  eventually a domain. None of that is a secret in the
  [03](03-secrets-handling.md) sense, but all of it is a map of the house.
  Private is the obvious default; state the reason so it is a decision, not a
  reflex.
- **How Komodo authenticates.** A git account + HTTPS token in Komodo, and where
  that token itself lives — it is a secret, so it interacts with
  [03](03-secrets-handling.md), but it is the *bootstrap* secret: it cannot live
  in the repo it unlocks.
- **What gets pushed now.** Today the repo holds this map's markdown under
  `.scratch/`. Decide whether the wayfinder artifacts travel with the repo or
  stay local — and whether the inventory asset, which describes the box in
  detail, is comfortable on a private remote.
- **Confirm the box can actually reach it** — a hand-off checklist per the map's
  Box access note.

**HITL**: creating the remote and holding the token is the human's, and the
reachability check runs on the box.

The answer records the remote's URL, its visibility, how Komodo authenticates,
and where the token is kept.
