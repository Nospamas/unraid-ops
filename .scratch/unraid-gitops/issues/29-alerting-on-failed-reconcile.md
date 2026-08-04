# 29 — Give `failure_alert` somewhere to go

Type: grilling
Status: resolved

## Question

Graduated out of the map's fog by [16](16-deploy-caddy.md), which stopped it
being hypothetical. `procedures.toml` has `failure_alert = true` and **no
alerter is configured to receive it**, so a failing reconcile is silent.

16 hit two silent failures in one session, and neither would have been noticed
without someone watching a terminal:

- A `procedures.toml` edit the scheduled Procedure **cannot** apply, so every
  cron reconcile failed outright — no Stack deployed at all — until someone ran
  `just reconcile` by hand.
- Caddy served nothing for several minutes after a stale bind mount, while the
  reconcile that caused it reported **success**. Nothing in Komodo was failing;
  the workload was.

Those are two different questions and the ticket has to separate them:

- **Which alerter, and reaching what.** Komodo ships several endpoint types.
  The constraint is that nothing is published, so a webhook out is fine but
  anything inbound is not. Whatever is chosen is git-owned like everything else
  ([07](07-repo-layout-and-conventions.md)) and its credential is SOPS
  ([03](03-secrets-handling.md)) — so this adds a seventh secret unless the
  choice avoids one.
- **Whether Komodo reporting success is enough.** The Caddy outage proves it is
  not. Decide whether this map wants liveness checking of the workloads at all,
  or whether that is a separate effort — Komodo alerts on *its own* actions, and
  a container that is up but serving 404s is invisible to it. Ruling this out of
  scope is a legitimate answer; leaving it unstated is not.

**A third sighting, from [21](21-migrate-arr-stacks.md)** — and it is the same
shape as the Caddy one, which makes it a pattern rather than an accident. Three
containers were left `Up` with no networks and no published ports by a deploy
that failed half-way. The *next* reconcile reported `Execution ok`, because
`DeployStackIfChanged` compares the config hash and the hash was right. Green
loop, three dead services, nothing anywhere saying so. Whatever this ticket
decides about liveness has now been argued for twice by events.

Also revisit: [12](12-image-update-strategy.md)'s four human-merge carve-outs
were explicitly **the stand-in for monitoring**. If something is now watching,
say whether they stay.

Not blocked. Nothing in the map depends on it, which is exactly why it has been
deferred twice.

## Answer

**Two Stacks, one Alerter, and no new secret.** Alerts land in a self-hosted
`ntfy` on the box, reached by an Android client over the tailnet. `gatus` probes
every fronted service end to end and publishes there; Komodo's Alerter publishes
`ProcedureFailed`, `StackStateChange` and `ServerUnreachable` to the same topic.

The ticket predicted a seventh secret "unless the choice avoids one". It avoids
one: self-hosted with tailscale as the trust boundary means there is no webhook
URL or token to encrypt.

### The ticket's premise about Komodo was wrong, and it did not matter

`AlertData` has **22 variants**, not just `ProcedureFailed`. `StackStateChange`
exists and means "a stack's state has changed unexpectedly", and `StackState`
has an `Unhealthy` variant. So Komodo *does* poll workload state independently
of its own actions.

It still catches none of this map's three silent failures, because all three
were containers that stayed `Up`:

- Caddy discarded every block importing the missing `internal` snippet and
  served nothing — the process was healthy [16]
- three *arr were `Up` with no networks [21]
- the failed cron is `ProcedureFailed`, which an alerter alone does cover

`Unhealthy` means a *mix* of container states. There was no mix. That is the
whole argument for probing rather than trusting Komodo, and it is why liveness
was ruled in scope rather than deferred again.

### The 403 that would have made every probe meaningless

A gatus container on `shared` probing `https://sonarr.rbrb.in` arrives at
host-networked Caddy with its **bridge source address** — no masquerade applies
to traffic destined for the host's own IP — and `(internal)` answers **403
before `reverse_proxy` runs**. Every probe fails identically, and a 403 proves
only that the guard works.

So **gatus is host-networked**, for [16]'s reason rather than by preference.
Probes then arrive from `192.168.1.195` and the guard admits them, testing the
real path: DNS, cert, guard, proxy, backend.

Rejected alternative: adding `172.20.0.0/16` to the guard. It would admit every
container on `shared` through Caddy to buy one probe, and the guard is currently
the only thing in front of qbittorrent's unauthenticated API [24].

### The rule this produced

> **The alert path must not traverse the thing it reports on.**

Komodo Core is on the bootstrap network, not `shared`, so it hits the same 403
publishing to `ntfy.rbrb.in`. But the deeper point is that routing alerts
through Caddy means a Caddy outage silences the alert about the Caddy outage.

So `ntfy` takes **no `caddy` label at all** and binds the tailnet address
directly — `100.126.56.26:8095`, following CoreDNS's precedent and inheriting
its reboot race. One bind serves every party: the phone, Komodo Core, gatus,
and — once the operator lands — home-ops. Nothing on rb's LAN can reach it, and
nothing there needs to.

This widened [26]'s third host-port reason from *repairs* to **detects or
repairs**. gatus keeps `:8090` alongside `status.rbrb.in`, which is a fourth
qualifier where 26 said "three and no more".

### Six of ten services do not answer 200

Measured against the running box rather than assumed, which is the find that
would have made a naive config alert constantly:

| 200 | homepage, qbittorrent, komodo |
| 302 | sonarr, radarr, prowlarr, unraid |
| 303 | lazylibrarian |
| 401 | calibre, plex |

So conditions assert an **exact** status. Two signatures matter: **404** is
Caddy having dropped the block and the `*.rbrb.in` wildcard catching the request
— [16] exactly — and **502** is Caddy holding the block but unable to reach the
container, which is [21].

An eleventh probe is DNS: `sonarr.rbrb.in` against `100.126.56.26`, asserting
`NOERROR` and an answer of `100.126.56.26`. The public record is
`192.168.1.195`, so that assertion tests the **tailnet view specifically** — the
only end-to-end check of [17] and [18]'s split horizon, verified once by hand
and never since.

The qbittorrent probe is the one that earns its place twice: it is the only
thing that would ever report [06]'s hazard, where recreating gluetun alone
leaves qbittorrent in a dead namespace with no route and no error.

### Discipline

60s interval, **three** consecutive failures, `success-threshold: 2`,
`send-on-resolved`. A reconcile that legitimately redeploys a Stack takes it
down for seconds, and paging on that is how a channel gets muted; blips stay in
the status page's history. SQLite in appdata rather than memory storage —
memory loses history on restart, and gatus restarts when its config changes,
which is exactly when you are investigating.

Komodo's `failure_alert` has **no dedup**, so [16]'s broken cron would have
notified every 15 minutes for hours. Chosen, not discovered: a wholly broken
reconcile loop should be loud.

### [12]'s carve-outs, revisited as asked

12 held five paths at human merge because "a bad version is expensive and
nothing is watching — **monitoring is still fog**". Half that reason is now
false, and it splits per row rather than all at once:

- **`stacks/download/**` released.** Its stated reason — that Komodo recreating
  both unaided was unverified — was spent by [24], and the qbittorrent probe is
  a direct detector. Still grouped into one PR, since the pair must never bump
  apart.
- **`stacks/coredns/**` released.** The DNS probe watches it specifically.
- **`stacks/plex/**` stays.** gatus proves plex answers, not that a client can
  play from it.
- **`stacks/caddy/**` stays.** A broken front door costs the same to repair
  however fast you hear about it.
- **`bootstrap/**` stays.** 12 carved it out for an unrelated reason.

Added: **`stacks/ntfy/**` and `stacks/gatus/**` are human-merge**, because
nothing on tower watches the watcher. That retires when home-ops probes tower.

### What this does not close

**Box-down.** ntfy and gatus both die with the box, so silence remains
indistinguishable from health — and self-hosting on tower makes this *worse*
than a third party would, since the notification server is now part of the
outage.

The chosen fix is cross-site: each site runs its own ntfy, each site's alerting
goes to its own, and each site's gatus probes the other. Notably this needs
**no cross-site credential** — neither site ever writes to the other's ntfy,
only reaches it.

tower's half is built and ready: `ntfy` and `gatus` are tailnet-reachable by
construction. home-ops's half does not exist and cannot yet, because
`grep -ril tailscale kubernetes/` returns nothing — the Talos cluster is not on
the tailnet. Specified in
[assets/29-home-ops-alerting-brief.md](../assets/29-home-ops-alerting-brief.md),
which is home-ops's work, not this map's.

Two things found while scoping that home-ops needs to know: its gatus has no
`alerting:` block either, and its entire `alertmanagerconfig.yaml` is commented
out — so it has the same disease. Its `PUSHOVER_USER_KEY`,
`ALERTMANAGER_PUSHOVER_TOKEN` and `HEALTHCHECKS_IO_HEARTBEAT_URL` are **template
residue for accounts that do not exist**, and should be deleted rather than
revived.

### Deploy note

`komodo/procedures.toml` changed, so **`just reconcile`, never the cron** — the
scheduled run fails outright until someone runs the recipe [16].

`ntfy` precedes `gatus` in the pattern. Ports 8090 and 8095 were confirmed free
on the box before choosing them.

**Not verified against a running box.** Nothing here has been deployed. The
Komodo Alerter TOML shape in particular is written from `AlerterConfig`'s field
list and this repo's existing `[x.config]` convention, not from a Komodo example
— the first `just reconcile` is its first real test.
