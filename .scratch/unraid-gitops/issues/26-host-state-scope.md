# 26 — Decide how much of the box's host state git owns

Type: grilling
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03

## Question

Surfaced by [15](15-move-unraid-gui-ports.md). Moving the GUI's ports needed a
setting that lives on the flash at `/boot/config/ident.cfg`, which Komodo cannot
see and no ResourceSync will ever reconcile. 15 built the narrow answer — a
snapshot in [bootstrap/host/](../../../bootstrap/host/) plus `just host-ports`,
which applies **only** the Management Access fields — and deliberately stopped
there. This ticket decides the general rule.

The map's **Container scope** note settles which *containers* git owns and is
emphatic about no two-tier box. There is no equivalent ruling for the host
underneath them, and 15 has now put one foot in that territory.

What has to be decided:

- **Which host settings, if any, git owns.** `ident.cfg` alone holds share
  security mode, NTP servers, timezone, workgroup, mDNS TLD and the array slot
  count. Beyond it sit `/boot/config/` at large — network config, shares, disk
  settings, the plugin list, `go`. The honest options run from *ports only*
  (today) through *record everything, apply nothing* to *git owns the flash*.
- **Snapshot or source of truth.** 15's file is a snapshot: the box wins, and
  `just host-check` exists to stop the record going stale silently. A setting
  git genuinely *owns* would invert that — the GUI becomes the wrong place to
  change it, which is a real cost on a box whose GUI is how the human works.
- **What applies it.** `emcmd` reaches emhttpd for the pages that have a
  handler; other settings are files that need a service reloaded, and some need
  a reboot. There may be no single mechanism, which is itself an answer.
- **Whether drift is checked, and by what.** `host-check` is one recipe run by
  hand. If host state grows, the question is whether it joins `just lint` and
  CI — noting CI cannot reach the box.

**Do not let this become a general Unraid-configuration-management effort.** The
map's destination is a `git push` that reconciles *containers*; the array,
shares and disks are already out of scope. The test for anything here is whether
losing the setting would break the stack or the rebuild story — the ports do,
which is why 15 happened at all. If the answer turns out to be "ports only, and
the rest is a snapshot", that is a legitimate result and this ticket closes
having ruled the rest out of scope.

Related fog: **Appdata backup and box rebuild** on the map. Both are about what
a rebuild actually takes, and this ticket should not answer that half — but the
two will want reading together.

**HITL**: a scope decision, so `/grilling`.

Blocks nothing. Nothing blocks it — 15 already shipped the piece the stack
needed.

## Resolution (2026-08-03)

**Ports only — and the ticket was asking the wrong question.** `ident.cfg`'s
Management Access fields stay the whole of what git owns, `host-ports` and
`host-check` are unchanged, and the rest of `/boot/config/` is **out of scope**.
But the answer that matters is what replaced the question: the reason to want
host state in git was that things address the box by IP, and the fix is to stop
addressing the box by IP.

### Every candidate was tested and every one failed

Not waved off — each was checked on the box first, and each shrank:

| candidate | why it failed the test |
|---|---|
| `docker.cfg` `DOCKER_APP_CONFIG_PATH` | Stack binds come from `APPDATA` in `common.env`. This copy is unraid's Docker-tab template default and reaches nothing the repo deploys. Cosmetic. |
| `/boot/config/ssh/root.pubkeys` | 101 bytes and it is the lifeline, so it is tempting. It is the human's *public* key, held in their own tooling, and a fresh flash puts the GUI back on 80 to paste it in. Recoverable by hand. |
| tailscale `CorpDNS: false` | A real invariant [18] and one command to read. But if it flips, tower hairpins to its own host-networked Caddy over WireGuard — degraded, not broken. |
| `network.cfg` | See below. Owning it would record a lease, not pin one. |
| `shares/`, `pools/`, `disk.cfg`, `super.dat` | The storage layer, already out of scope. |
| `passwd`, `shadow`, `smbpasswd`, `secrets.tdb`, `Lifetime.key` | Secrets and a licence. Rules out "git owns the flash" on its own. |

### The one that passes, and git cannot have it

**`192.168.1.195` is a DHCP lease.** `network.cfg` says `USE_DHCP[0]="yes"`, `ip
addr` says `dynamic`, and `grep -rn 192.168.1.195 /boot/config/` returns
**nothing**. The address the whole map leans on is not on the box at all — it is
in rb's router, which [the map](../map.md) is explicit is "none of ours".

So the fix cannot be ownership. It is either a reservation (off-box, handed to
the human) or removing the dependency — and after [30](30-arr-urls-on-shared.md)
the only thing still betting on it is Cloudflare's `*.rbrb.in` A record, whose
failure is bounded to rb's network and repaired by one Cloudflare edit. The
tailnet path resolves via CoreDNS to `100.126.56.26` and is untouched.

### The rule this ticket actually produced

In [docs/conventions.md](../../../docs/conventions.md) under **Addressing**:
humans reach a service at its `*.rbrb.in` hostname, containers reach each other
by container name on `shared`, and **neither is ever the box's address**. A host
port is the exception and must name its reader in `x-host-port`.

**Three reasons qualify, and nothing else.** A client configured by address
(CoreDNS, because tailscale's Split DNS row takes an IP); **plex's `32400`,
which is its own carve-out** and not a general licence, because plex.tv
advertises that address and rb's router forwards it — [31](31-plex-own-internet-exposure.md)
still owns how the repo says so; and **a backup path to whatever repairs
Caddy**. That last one was not on the ticket and is the reusable part: *the
tooling that fixes the proxy must not sit behind the proxy.*

### `komodo.rbrb.in` and `unraid.rbrb.in`, and they keep their ports

Two static blocks in [the Caddyfile](../../../stacks/caddy/conf/Caddyfile) —
these are the two human-facing UIs on the box that are **not Stacks**, so they
have no compose file to carry a `caddy` label. `reverse_proxy localhost:...`
works because Caddy is host-networked [16].

`:9120` and `:8008` stay bound deliberately, which is the human's call and the
right one: a Caddy that will not start must not take Komodo with it.

Verified over the tailnet: `komodo.rbrb.in` 200, `unraid.rbrb.in` 302 → `/login`
200, `home.rbrb.in` still 200, an unmatched name still 404, and both direct
ports still 200. A container on `shared` gets **403** on both new hostnames, so
the `internal` guard is inherited rather than assumed.

**Two things worth knowing.** Caddy picked the new Caddyfile up **without a
redeploy** — the bind is a directory and `caddy-docker-proxy` re-reads its base
on each generation cycle, so `DeployStackIfChanged` seeing no config change was
harmless here rather than the silent failure [16] and [21] warn about. And
unraid redirects to `http://unraid.rbrb.in/Main` in plain http, which Caddy
upgrades again — one extra hop, because unraid's nginx does not read
`X-Forwarded-Proto`. Left alone.

### `x-host-port`, and what it caught

A Service key beside `x-published` in
[check-exposure.sh](../../../scripts/check-exposure.sh), which now fails any
`ports:` block that does not name its reader. Deliberately **not** the same
question as `x-published` — it asks who the port is for, not whether the
internet can see it, so a Service can need both and [31] stays free to decide
their relationship.

It found one thing immediately. **[lazylibrarian](../../../stacks/lazylibrarian/compose.yaml)'s
`5299` has no reader at all** — kept as found by [21], never addressed by
anything, and its old comment ("Nothing addresses it by host today") was an
admission dressed as a justification. It now says so in the key, and
[30](30-arr-urls-on-shared.md) deletes it. The other five — the four *arr and
`download`'s `30024` — carry keys saying they break the rule pending 30, so key
and port come out together.

Verified by deleting plex's key and watching lint fail, not by watching it pass.

### What this does not do

No lint check on the addressing rule itself — only on host ports. A service
given an IP-based in-app URL through its own web UI is still invisible to the
repo, because that config lives in appdata. That is [30]'s territory and,
longer term, the reason the *arr URLs went wrong in the first place.
