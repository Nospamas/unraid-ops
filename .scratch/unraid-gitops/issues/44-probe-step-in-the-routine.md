---
id: "44"
title: Give the routine its gatus-probe step
type: task
status: closed
description: >
  Step 7b, plus scripts/check-probes.sh — a step alone would have been the same
  prose that already failed, because a missing probe is the one fault with no
  signature. The step carries the judgement, the check carries the fact; ntfy's
  browser door turned out to be the gap and got probed rather than excepted.
touches:
  [
    docs/adding-a-service.md,
    docs/conventions.md,
    scripts/check-probes.sh,
    stacks/gatus/conf/config.yaml,
    justfile,
  ]
---

# 44 — Give the routine its gatus-probe step

Blocked by: —
Resolved: 2026-08-07

## Question

[adding-a-service.md](../../../docs/adding-a-service.md) runs from *make the
directory* to *check it* and never mentions gatus. The probe lives in the
**Traps** section, which is where a reader goes when something has already gone
wrong — so a service added by following the routine end to end is
**unmonitored**, and nothing catches it, because a missing probe has no failure
signature.

[35](35-add-tautulli.md) only added one because the ticket said to.

Decide whether it becomes a numbered step, and if so what it carries — because
the probe is not a copy-paste line:

- **the endpoint is a choice.** Every probe in
  [config.yaml](../../../stacks/gatus/conf/config.yaml) hits `/` except
  tautulli's, which hits `/status` — its root moves between 303, 200 and 302 as
  the setup wizard and the auth setting change, and a probe cannot assert a
  status that appdata governs [35].
- **the status is measured, not assumed** [29]. Six of the ten were not 200.
- **it cannot be measured before the first deploy**, so the step lands after
  step 7 and the routine currently ends at step 8.

Whether the same is owed to the `BatchDeployStackIfChanged` list — which *is* in
the routine, at step 7 — is not in question; it is there and it works.

## Resolution

**A step and a check, because they do different jobs.** The question offered
"numbered step or not", and the step alone would have failed the same way the
Traps entry did: the probe was already written down, and [35] got one because
its ticket said to. Moving prose earlier makes it read earlier, not happen.

What settles it is the asymmetry in the failure. **A missing probe has no
signature** — nothing is down, nothing 404s, the service is simply absent from
the status page, forever. Nothing in this repo catches an absence, so the
absence had to become a lint failure. The step then carries what a check cannot:
the endpoint is a choice and the status is measured.

### Step 7b, not 9

Forced by two constraints meeting. The status cannot be measured before the
first deploy, so it lands after step 7; and step 8's `just lint` now demands the
probe, so it lands before step 8. The letter suffix follows 4b/5b/6b/8b and
renumbers nothing.

It also has to say **the cron applies this one**. Step 7 shouts *do not wait 15
minutes*, which is true of `procedures.toml` and of nothing else — a reader who
generalises it reaches for `just reconcile` on every config edit. gatus's
`conf/config.yaml` is a tracked config file with `requires = "restart"`.

The step carries five things, four of them already-paid-for reasoning: measure
the exact status [29]; `/` unless the root moves under an appdata setting
[35, 36]; verify the route is the backend and not the app shell; and
`ignore-redirect: true` per endpoint [29]. The third was generalised out of
bazarr's specifics — [36] keeps the worked example, the routine states the
check.

### The check is file-only, and one-way

[scripts/check-probes.sh](../../../scripts/check-probes.sh) compares the
`caddy:` hostnames in `stacks/*/compose.yaml` against the endpoint URLs in
`stacks/gatus/conf/config.yaml`. **It issues no request.** A lint that reached
the box would fail in CI, and would report "this service is down right now" as
"the repo is broken" — two different problems, and only one of them is the
lint's.

Matching is on the URL's **host**, not the whole URL: tautulli and bazarr probe
a path below the root [35, 36], so the hostname is the only part a label can be
compared against.

**One direction only.** The reverse — every probe has a Stack — would catch a
stale probe left behind by a removed service, but it would false-positive on
`komodo`, `unraid`, `bare domain` and `coredns`, which front nothing or live in
the Caddyfile [29], so it would need a hand-maintained allowlist. It buys
nothing anyway: a stale probe fails loudly by itself. The check exists for the
fault that does not.

### ntfy was the one gap, and it got probed rather than excepted

Ten of eleven fronted hostnames already had a probe. `ntfy.rbrb.in` did not, and
the first instinct — that home-ops already covers ntfy — is about the **other
door**: home-ops probes `100.126.56.26:8095/v1/health`, the tailnet address.
Caddy discarding ntfy's block alone would leave the phone and the publishers
working and nothing noticing until someone opened a browser.

So `https://ntfy.rbrb.in/v1/health` is now probed, 200 and `[BODY].healthy ==
true`, measured against the box rather than assumed. It is the rare probe that
can page about itself: the failure it catches leaves ntfy up, so the alert
delivers over `:8095`. The case where it could not — ntfy itself down — is
home-ops's, by design [29].

That left **zero exceptions**, so the check ships with no opt-out key. An
`x-unprobed:` mirroring `x-published` was drafted and dropped: an escape hatch
that exists gets used, and a service that genuinely should not be probed is
worth a conversation. Same line the repo takes on `caddy.import: internal`.

### Verified

`just lint` green — `probes ok -- 11 fronted service(s), all probed` — and the
check was proven to fail rather than pass vacuously by pointing bazarr's probe
at a hostname no Stack claims.
