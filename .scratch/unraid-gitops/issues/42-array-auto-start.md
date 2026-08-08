---
id: "42"
title: Make the array come back on its own after a reboot
type: task
status: closed
description: >
  The array starts itself, and `startArray` is recorded as an **assertion** —
  a named flash key `host-check` reads and never applies — not a second
  snapshot. It also gave 26's admission test a third limb: *or leave the box
  needing a human to recover from something it used to recover from alone*.
  The limb is about silence, not severity: `DOCKER_ENABLED` fails it because
  `just bootstrap` dies loudly without it.
touches: [scripts/host.sh, justfile, docs/conventions.md, bootstrap/README.md]
---

# 42 — Make the array come back on its own after a reboot

Blocked by: —
Resolved: 2026-08-07

## Question

`/boot/config/disk.cfg` reads `startArray="no"`. A power cut or a reboot brings
the box up with SSH and the GUI on `:8008` reachable and **every service down** —
docker's root is on the array, so nothing starts until a human opens the GUI and
clicks Start. Not a lockout, but a total outage that waits on a person.

The container half is already right and needs nothing: all containers carry
`restart: unless-stopped`, verified against the box at
[25](25-retire-portainer.md). `/var/lib/docker/unraid-autostart` is empty and
that is correct — it only ever governed Portainer, which was the one container
Unraid's Docker tab owned rather than Komodo.

**No encryption stands in the way.** Six xfs, one btrfs, one vfat, zero LUKS
devices, and `/dev/mapper/` holds only `control`. The `luksKeyfile="/root/keyfile"`
line in `disk.cfg` is Unraid's inert default and no such file exists. Auto-start
needs no key and no passphrase.

### Do not write disk.cfg over SSH

`disk.cfg` was last written at **02:52:46 on 2026-08-03, three and a half minutes
after the 02:49:10 boot** — emhttpd rewriting it from its own state at array
start. `startArray` also lives in emhttpd's in-memory
`/var/local/emhttp/var.ini`. A direct file edit is therefore liable to be
overwritten at the next array start: it would fail silently at exactly the moment
it was supposed to work.

This is the trap [scripts/host.sh](../../../scripts/host.sh) already documents for
`ident.cfg` — "copying the file into place would update neither" — which is why
`host ports` drives emhttpd through its socket instead.

So the change itself is a GUI action: **Settings → Disk Settings → Enable auto
start → Yes → Apply**, then confirm `disk.cfg` reads `startArray="yes"`.

It is the first field of the main form in
`/usr/local/emhttp/webGui/DiskSettings.page`, outside any array-stopped guard, so
on Unraid 7.3.2 it applies **with the array running** — no outage to make the
change.

### The decision this ticket carries

[26](26-host-state-scope.md) ruled git owns exactly one piece of host state,
`ident.cfg`'s Management Access fields, because a fresh flash puts nginx back on
80/443 where Caddy cannot bind [15]. Every other candidate failed "would losing
this break the stack or the rebuild".

`startArray` is a new candidate and it is not obviously the same answer: losing it
does not break the stack, but it does mean a rebuilt flash silently drops back to
a box that needs a human after every power cut. Decide **how it is recorded** so a
rebuild restores it:

- a second snapshot beside `bootstrap/host/ident.cfg`, with `host.sh check`
  extended to diff it — but `disk.cfg` also holds disk slot assignments, which are
  the machine's, not git's, so a whole-file snapshot brings along state 26 ruled
  out;
- or a single asserted key rather than a file, which means teaching `host.sh` to
  read and compare one setting instead of diffing a snapshot;
- or documentation only, in the rebuild story, on the grounds that a checkbox a
  human ticks once is not worth a mechanism.

Whichever wins, apply it to the **class**, not just this key — the answer decides
what happens the next time a box setting matters, and stating it once is the
point.

## Resolution (2026-08-07)

**An assertion, not a snapshot** — and the interesting half is the test that
admits one.

### The third limb

[26](26-host-state-scope.md) admitted host state on "would losing this break the
stack or the rebuild", and every candidate it tried failed. `startArray` fails
it too, on a technicality: losing it breaks no service, because the array comes
up the moment someone clicks Start, and it does not break a *rebuild*, because a
rebuild has a human standing at the GUI clicking Start regardless.

What it breaks is what happens **months later**. So the test grows a third limb,
now in [docs/conventions.md](../../../docs/conventions.md) beside 26's ruling:

> or leave the box needing a human to recover from something it used to recover
> from alone.

**The limb is about silence, not severity**, which is what keeps it narrow. The
sweep for other members found one near miss and it fails: `DOCKER_ENABLED="yes"`
is more catastrophic to lose — nothing runs at all — but a rebuilt flash without
it does not fail quietly, `just bootstrap` dies at the `docker run` in step 6.
The `plugins/*.plg` that bring tailscale back are out for the same reason. One
member today.

### Why not the file

A `disk.cfg` snapshot beside `bootstrap/host/ident.cfg` was the obvious shape and
it is wrong: `disk.cfg` also carries the disk slot assignments, which are the
machine's and which 26 ruled out — so every disk change would read as drift, and
the record for one checkbox would drag the storage layer into git. The assertion
is a **named key and its expected value**, in `assertions` in
[scripts/host.sh](../../../scripts/host.sh), each entry carrying the reason and
the GUI path that fixes it.

### Check-only

An assertion applies nothing. `host-ports` reaches emhttpd over its socket
because the Management Access page is git's; doing the same for `startArray`
would make this repo an owner of array settings, which is past 26's boundary. A
failed assertion prints Settings → Disk Settings → Enable auto start → Yes →
Apply, and stops.

`check` runs the assertions **after** the `ident.cfg` diff and combines the exit
codes rather than returning early — a drifted snapshot must not hide a failed
assertion. One extra ssh, read-only, so `host-check` stays ungated.

Verified by watching it fail, not pass: a deliberately wrong expected value gives
`** ... expected "NOPE"` and exit 1, and a key that does not exist reports
`<unset>` rather than matching an empty string.

### What runs it

Nothing scheduled — it stays hand-run, as `host-check` already was. That is
enough because [bootstrap/README.md](../../../bootstrap/README.md)'s rebuild
section already calls `host-check` immediately before `host-ports --apply`, which
is the exact moment a fresh flash is missing the setting. Drift afterwards is a
human deliberately unticking the box, which is a decision rather than rot.

## The checkbox was done (2026-08-05)

Set through the GUI with the array running; nothing restarted. `disk.cfg` and
emhttpd's `var.ini` both read `startArray="yes"` — they **agree**, which is the
evidence a file edit could not have produced.

## Hand-offs

None left.
