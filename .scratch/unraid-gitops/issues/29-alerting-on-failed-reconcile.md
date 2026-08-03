# 29 — Give `failure_alert` somewhere to go

Type: grilling
Status: open

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
