---
id: "42"
title: Make the array come back on its own after a reboot
type: task
status: open
description: >
  The array now starts itself — the checkbox is done, verified in both
  `disk.cfg` and emhttpd's `var.ini`. What remains is how `startArray` is
  recorded so a rebuilt flash gets it back, answered for the class of box
  settings rather than this one key.
touches: []
---

# 42 — Make the array come back on its own after a reboot

Blocked by: —
Claimed by: wayfinder session, 2026-08-07

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

## The checkbox is done (2026-08-05)

Set through the GUI with the array running; nothing restarted. `disk.cfg` and
emhttpd's `var.ini` both read `startArray="yes"` — they **agree**, which is the
evidence a file edit could not have produced.

So the outage is fixed and what remains is only the recording decision above. Do
not reopen the box side; open the question of whether a rebuilt flash gets this
back.

## Hand-offs

None left.
