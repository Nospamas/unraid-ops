---
id: "53"
title: Make the lint force a headless Stack's x-watch statement
type: grilling
status: open
description: >
  46 ruled that a Stack with no listener declares `x-watch` and argues its own
  case, and wrote that into the routine — where prose alone already failed
  once [44]. Nothing checks it. The check is cheap; the cost is that it
  retrofits four existing Stacks that each need a true answer.
touches:
  - scripts/check-probes.sh
  - docs/conventions.md
---

# 53 — Make the lint force a headless Stack's x-watch statement

Blocked by: —

## Question

[46](46-add-recyclarr.md) added `x-watch` — a sentence on a Service with no HTTP
listener, naming what notices when it stops, where `nothing, because …` is legal
and argued per Stack. It lives in
[docs/adding-a-service.md](../../../docs/adding-a-service.md) step 7c and in
`conventions.md`, and **nothing enforces it**.

That is precisely the shape [44](44-probe-step-in-the-routine.md) rejected. Its
finding was that moving the prose earlier would not have worked, because a
missing probe has no failure signature — nothing is down, nothing 404s, the
service simply never appears. A missing `x-watch` is worse: the Stack is not
merely unwatched, nobody ever asked whether it should be.

`check-exposure.sh` is the model. It does not ask whether a Service *should* be
internal; it asserts that the question was answered, and `x-published`'s value
is prose it never reads. `x-watch` is the same shape.

### What it costs

The check is a few lines. The retrofit is the decision. A Stack with no fronted
Service today:

- `dockerproxy` — no listener anyone dials by name
- `coredns` — not fronted, but **is** probed, by a DNS endpoint [29]
- `caddy` — not fronted by itself; `status`/`komodo`/`unraid` are its own blocks
- `gatus` — host-networked, so caddy-docker-proxy never sees a label [29]

Plus `qbittorrent`, a Service carrying no labels of its own because they sit on
gluetun [06] — yet it is probed, through `127.0.0.1:30024`.

So the naive rule *"no `caddy:` label ⇒ needs `x-watch`"* is wrong for four of
the five: they are watched, just not through a label. **Decide what the check
actually keys on** — the absence of any probe reaching that Stack, rather than
the absence of a hostname — and whether `x-watch` is then required only where
the answer is genuinely nothing.

Check-only and hermetic: it reads repo files and issues no request, for
`check-probes.sh`'s stated reason.

### Out of the way of this one

[48](48-add-unpackerr.md) does **not** need this. `UN_WEBSERVER_LISTEN_ADDR`
gives unpackerr a listener, so it fronts and probes like anything else — the
fog entry that paired it with 46 was wrong on that point.

## Hand-offs

To be recorded on resolution.
