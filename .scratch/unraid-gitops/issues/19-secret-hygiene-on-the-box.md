---
id: "19"
title: "Settle secret hygiene on the box: appdata permissions and the old plaintext copies"
type: grilling
status: closed
description: >
  Periphery's umask is 0022, so every decrypted `secrets.env` was 0644;
  `(umask 077; sops -d …)` fixes it and `just lint` enforces it. The boundary
  is not directory perms — appdata is exported over neither SMB nor NFS.
  `/boot` holds no WireGuard key (01 was wrong); the calibre password is the
  asset there.
touches: [scripts/check-secrets-mode.sh, scripts/permissions.sh, docs/conventions.md]
---

# 19 — Settle secret hygiene on the box: appdata permissions and the old plaintext copies

Resolved: 2026-08-03
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

## Resolution

**The boundary 03 assumed was not there, and the reason was one bit.**

Periphery's umask is **0022**, so `sops -d secrets.sops.env > secrets.env` — a
plain redirect — created every decrypted secret **0644, world-readable**. Both
live ones were: homepage's and caddy's, the latter holding the Cloudflare DNS
token. Proven inside the container rather than inferred: a bare redirect there
yields 644, the same redirect under `(umask 077; ...)` yields 600.

The fix is the subshell, not a `chmod` afterwards — it closes the window instead
of reopening it a moment later. [scripts/check-secrets-mode.sh](../../../scripts/check-secrets-mode.sh)
is in `just lint` so a new Stack cannot reintroduce the bare form.

**Who could actually read it: nobody, yet.** `appdata.cfg` has
`shareExport="-"` *and* `shareExportNFS="-"` — the share is exported over
neither protocol — and no container binds the tree except `komodo-periphery`,
which writes it. Every workload binds only its own Stack subdirectory. The
exposure was latent, one unrelated click away: enabling SMB on appdata, or one
container bound at `/mnt/user/appdata` instead of its own subdirectory.

### The 777 was a stopgap, and this ticket found what it was standing in for

Not a secrets question at first sight, but the same tree. The box had been
`chmod -R 777`'d because **rb could not move media**: every *arr runs
`UMASK=022`, creating 755 directories owned `nobody:users`, and rename/delete
needs write on the **parent directory**, not the file. `nobody`(99),
`share`(1000) and `rseaforthb`(1001) all have primary gid **100** already —
`id` confirms it, no group edit was needed — so `UMASK=002` and group-write is
the whole cure. That is [09](09-unify-uid-gid.md)'s decision, unexecuted.

**Samba is not implicated.** Its effective `create mask` and `directory mask`
are both **0777**; it strips nothing. Do not "fix" `smb-extra.conf`.

### What was actually on the box

- **`/boot` holds no WireGuard key.** [01](01-inventory-running-containers.md)
  said it did; nothing in `/boot/config` matches. 03's "Unraid Connect ships
  `/boot` off-site" worry never applied to it.
- **The calibre GUI password *is* on `/boot`**, cleartext in
  `dockerMan/templates-user/my-calibre.xml` (600, dir 700). `Mask="true"` only
  hides it in the UI. **The off-site concern attaches to the other asset** —
  inverted from what 01 and 03 assumed. Still low-value per the map; recorded,
  not actioned.
- **Portainer's copies are the best-protected on the box** — 600 in a 700 dir.
  But `portainer.db` **and `backups/portainer.db.bak` hold the key too**, and
  nobody had counted the database. [25](25-retire-portainer.md)'s "keep it as a
  cold archive" option would preserve it.
- **`/mnt/user/appdata/scratch`** — 777, world-writable, with executable scripts
  in it: [01](01-inventory-running-containers.md)'s leftovers, exactly the
  unowned directory this ticket predicted. Its contents are already in
  [assets/](../assets/). **Deleted.**
- The `adopt/` copy is 600 root and dies with [24](24-migrate-download-stack.md).

### Delivered

`just permissions` / `just permissions-audit`
([scripts/permissions.sh](../../../scripts/permissions.sh)), dry-run by default
per [27](27-recipe-safety-convention.md), with a gzipped manifest of every mode
and owner as the rollback. After:

| | before | after |
|---|---|---|
| media dirs world-writable | 10,761 | **0** |
| media files world-writable | 76,903 | **0** |
| appdata paths world-writable | 2,663 | **0** |
| media dirs without `g+w` | 73 | **0** |
| `plexmediaserver` paths off-uid | 155,334 | **0** |

**The dry run caught a bug in the recipe before it ran.** An absolute `chmod
664` across appdata would have stripped the execute bit from
`komodo/bin/sops` — the decrypt itself — and from the codecs plex downloads
into its own appdata and then runs. Appdata is adjusted **relatively**
(`o-w`, `g+w`); only media takes absolute modes. `komodo/{postgres,ferretdb,
keys,backups}` and `caddy/data` are pruned entirely.

### Ruling

**The boundary is not directory permissions.** It is that the share is exported
nowhere and only Periphery binds the tree; modes are defence in depth behind
that. Both now hold. The map's secret-severity ruling is unchanged — this was
about where copies sit, and rotation remains neither blocked nor scheduled.
