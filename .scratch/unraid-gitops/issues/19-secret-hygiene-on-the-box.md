# 19 — Settle secret hygiene on the box: appdata permissions and the old plaintext copies

Type: grilling
Status: open
Blocked by: 11

## Question

Graduated out of the map's fog by [07](07-repo-layout-and-conventions.md), which
supplied the last missing piece — the layout. The question was already sharp
before that; it now has a concrete tree to be asked about.

[03](03-secrets-handling.md) deliberately leaves decrypted plaintext on the
array: each Stack's `pre_deploy` writes `secrets.env` into its run directory
under `/mnt/user/appdata/komodo`. It named the boundary it relies on —
**directory permissions on the komodo appdata tree** — and did not verify it.
Unraid shares default permissively, so "the boundary is directory perms" is an
assumption until someone looks.

[01](01-inventory-running-containers.md) found two *other* plaintext copies
already on the box, predating this effort: the NordVPN WireGuard key and the
calibre GUI password, on `/boot` and in Portainer's appdata.

Settle:

- **What the permissions on `/mnt/user/appdata/komodo` actually are** once Komodo
  is installed and has written its first `secrets.env` — owner, group, mode, and
  what the share's export settings make of them. Then decide whether that is the
  boundary 03 assumed, and if not, what makes it so.
- **Who can read it in practice** — other containers with an appdata bind, SMB
  clients on the LAN, the Unraid Web UI file manager. The interesting answer is
  not the mode bits but who reaches them.
- **What happens to the old plaintext copies.** The `/boot` copy is the one that
  matters most, because [03](03-secrets-handling.md) noted `/boot` is what Unraid
  Connect ships off-site — and 03 kept the new age key off `/boot` for exactly
  that reason, while the old key copy is presumably still there. Portainer's
  appdata copies go when Portainer goes, but "when Portainer goes" is not the
  same as "deleted", and the dockerMan template XML holds values too.
- **Whether any of this changes the map's secret-severity ruling.** Probably not
  — see the map's Secret severity note, and **do not re-raise rotation as a
  blocker**. The assets are ruled low-value and the ruling stands. This ticket is
  about *where copies sit and who can read them*, which is a different question
  from whether these particular values are worth rotating.

Blocked by [11](11-stand-up-komodo.md): the komodo appdata tree does not exist
until Komodo is installed, and the first question cannot be asked of a directory
that is not there.

**HITL** throughout — per the map's Box access note, everything here is a
hand-off checklist: commands to run in the Web UI terminal, output pasted back.

The answer states the observed permissions, who can actually read the decrypted
files, what is done about the pre-existing copies, and when.
