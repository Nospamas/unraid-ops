# 10 — Publish the repo to a remote the box can reach

Type: task (HITL)
Status: closed
Assignee: Nospamas
Resolved: 2026-08-01

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

## Resolution

**`https://github.com/Nospamas/unraid-ops`, public, cloned anonymously. There is
no credential.**

### The remote

GitHub, as the fog assumed, but for three reasons rather than by reflex:
[12](12-image-update-strategy.md)'s Renovate candidate is a GitHub App,
[02](02-choose-reconcile-mechanism.md)'s deferred webhook path is GitHub-shaped,
and `Nospamas/home-ops` is already there — same account, same habits. A forge on
the box stays ruled out as the circular dependency this ticket named.

Repo name `unraid-ops`, matching `home-ops`. Local `master` was renamed to
`main` before the first push, to match home-ops and GitHub's default: free with
ten local commits and no remote, but a retarget of every Komodo resource and
Renovate's base branch once those exist.

### Public — and this ticket's central question dissolves with it

The ticket was written expecting private, and therefore expecting to have to
house a **bootstrap secret**: a token that unlocks the repo and so cannot live
in the repo it unlocks. Public means Komodo clones anonymously over HTTPS, and
that whole branch evaporates. Nothing to mint, nothing to store, nothing to
expire, nothing to restore on a rebuild. `bootstrap/compose.yaml` — which
[07](07-repo-layout-and-conventions.md) puts in git — stays clean, and
[03](03-secrets-handling.md)'s rebuild story stays exactly **clone + restore one
age key** instead of growing a second credential beside it.

The case *against* public was put and **withdrawn on evidence**, which is worth
recording so it is not re-litigated:

- The objection was that SOPS ciphertext in a public repo is permanent and
  unpublishable, so an age-key leak retroactively decrypts everything — and that
  [04](04-reverse-proxy-and-domain.md)'s **Cloudflare DNS-edit token is not
  low-value** the way the map's Secret severity note rules the NordVPN key and
  the calibre password to be. It can rewrite the whole `rbrb.in` zone.
- The evidence: `Nospamas/home-ops` is **public**, is built from the public
  `onedr0p/cluster-template`, and already commits `secret.sops.yaml` for
  `cloudflare-tunnel` and `external-dns-cloudflare` — the *same class of secret*
  as the one objected to. Public + SOPS ciphertext is a settled, working habit
  at this household, not a fresh exposure. Committing ciphertext publicly is
  what SOPS is *for*.

The "map of the house" half of the objection is weak and was dropped too:
`192.168.1.195` is RFC1918 and `100.126.56.26` is CGNAT inside a tailnet — both
meaningless to anyone not already on the network — and `rbrb.in` becomes public
in DNS the moment [14](14-cloudflare-zone-and-token.md) runs.

**Do not re-raise repo visibility.** It is decided, and the counter-argument has
already been answered.

### What ships: all of it, history included

`.scratch/unraid-gitops/` travels with the repo — the map, all twenty tickets,
and the assets, `assets/01-inventory.md` among them. The reasoning record is
load-bearing, not scratch: [docs/conventions.md](../../../docs/conventions.md)
and [CONTEXT.md](../../../CONTEXT.md) cite ticket numbers as their rationale, so
stripping `.scratch` would leave those docs pointing at nothing. Scrubbing the
inventory's addresses was considered and rejected — 04 and 05 quote both values
in their decisions anyway, so redacting the asset buys nothing and would have to
be redone at every re-inventory.

### Pre-publish audit — clean, nothing rewritten

Public exposes history, not just the working tree, so all ten commits were swept
before the first push:

- **No key material in any blob ever committed.** The only high-entropy strings
  are 64-hex **image digests**, which the inventory script itself flags as not
  secrets.
- **The on-box redaction held.** Every secret value in
  `assets/inventory-part2.out` reads `<<REDACTED — needs a secret>>` —
  `WIREGUARD_PRIVATE_KEY`, `PLEX_CLAIM`, calibre's `PASSWORD`/`CUSTOM_USER`, the
  OpenVPN set. [01](01-inventory-running-containers.md) scrubbed on the box, so
  plaintext never entered the repo in the first place.
- **Two files were ever deleted from history**, both harmless: an early
  `08-migrate-homepage.md`, and one `.claude/settings.local.json.tmp.*` holding
  a permissions allowlist — paths only, no credentials.

So **history was published as-is**. No rewrite, no squash.

That stray tmp file did expose a real hole, now closed: the workstation's global
ignore covers `**/.claude/settings.local.json` but **not** its `.tmp.*`
siblings, which is exactly how one got committed. `.gitignore` now ignores
`.claude/` wholesale — in the repo, not the global file, because a public repo's
clones do not inherit the global one.

### Handed to [11](11-stand-up-komodo.md)

Two facts this ticket could not settle from the workstation:

- **Whether Komodo accepts a Stack with no `git_account` set.** The docs read as
  though it is optional for public repos, but it is **unverified**. If it turns
  out to be mandatory even anonymously, the bootstrap-secret question this
  ticket dissolved comes *back*, and 11 should say so loudly rather than
  quietly minting a token.
- **Whether the box has working outbound HTTPS to `github.com`.** The
  reachability check runs on the box and is folded into 11's install checklist
  rather than run as a separate hand-off — 11 is already a box session, and a
  standalone `git clone` proves nothing that 11's first ResourceSync does not
  prove better.

### Consequences elsewhere

- The human pushes over **SSH** (matching home-ops, key already works); Komodo
  clones over **HTTPS anonymously**. Same repo, two paths, no conflict — the
  ticket's HTTPS-only constraint binds Komodo, not the human.
- **[12](12-image-update-strategy.md) gets cheaper**: Renovate's GitHub App and
  GitHub Actions minutes are both free on public repos, so cost is off that
  ticket's list of axes.
- **No new secrets.** The live count stays at six.
