# 26 — Decide how much of the box's host state git owns

Type: grilling
Status: open
Assignee: Nospamas

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
