# 19 — Settle secret hygiene on the box: appdata permissions and the old plaintext copies

Type: grilling
Status: open
Assignee: Nospamas
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

**A third copy of the WireGuard key now exists, made by
[11](11-stand-up-komodo.md)**: adopting the download stack needed its compose
file somewhere Periphery could see it, so it was copied to
`/mnt/user/appdata/komodo/adopt/download/docker-compose.yml` (600 root, in the
777 tree below). Scaffolding, not a decision — the migration deletes `adopt/`
when `stacks/download/` replaces it. Worth counting here because it means this
ticket is looking at *three* copies, and because a directory nobody owns is
exactly how a stale plaintext copy survives a cleanup.

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

## Early evidence, observed 2026-08-02 while placing the age key

Not a resolution — one `ls -al` handed over during [13](13-local-tooling.md)'s
hand-off, before Komodo exists. Recorded so it is not rediscovered:

```
drwxrwxrwx 1 root   root   14 Aug  2 01:22 ./      # /mnt/user/appdata/komodo
drwxrwxrwx 1 nobody users 208 Aug  2 01:22 ../     # /mnt/user/appdata
-rw------- 1 root   root    0 Aug  2 01:22 age.key
```

**`/mnt/user/appdata/komodo` is mode 777**, and so is `/mnt/user/appdata` above
it. This is the first direct look at the boundary
[03](03-secrets-handling.md) said it was relying on, and on this evidence
**the boundary 03 assumed is not there**. Note it is world-**writable**, not
merely world-readable — the more interesting half, since the tree will hold every
Stack's compose file and decrypted `secrets.env`.

The key file itself is `0600 root`, so the root secret is fine. The exposure is
what `pre_deploy` will *write*: `secrets.env` files created inside a 777
directory, with permissions set by whatever umask Periphery runs under. This
ticket still has to establish that umask and who reaches the share — the mode
bits above are one input, not the answer.

Whether 777 is Unraid's default for a hand-made appdata subdirectory or something
about how this one was created is also unestablished, and worth knowing before
deciding the fix is `chmod`.
