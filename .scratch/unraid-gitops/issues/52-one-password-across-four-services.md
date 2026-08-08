---
id: "52"
title: One password guards qbittorrent, calibre and lazylibrarian
type: grilling
status: closed
description: >
  The reuse is deliberate — convenience over security for internal-only web
  interfaces, and 19's ruling stands. The blast radius is also narrower than
  it looked: qbittorrent whitelists the whole of `shared`, so the *arr's
  copies of the password are never sent.
touches: []
---

# 52 — One password guards qbittorrent, calibre and lazylibrarian

Resolved: 2026-08-07
Blocked by: —

## Question

Surfaced by [41](41-orphan-unraid-templates.md), which grepped the box for the
calibre GUI password to prove the flash drive was clean and found it in five
more places. It is **one value**, reused:

| where | what it guards | protection |
|---|---|---|
| `stacks/calibre/secrets.sops.env` → run-directory `secrets.env` | calibre's GUI | age-encrypted in git, `0600` on the box |
| `sonarr.db`, `radarr.db`, `prowlarr.db` — `DownloadClients.Settings` | the *arr authenticating to qbittorrent | cleartext in appdata |
| `lazylibrarian/config.ini` — `qbittorrent_pass` | the same | cleartext in appdata |
| `lazylibrarian/config.ini` — `http_pass` | **lazylibrarian's own UI** | cleartext in appdata, plus `config.ini.bak` and `.bak-30` |

**The appdata copies are not the finding.** An *arr has to hold its download
client's password in cleartext to use it; that is how the application works and
no amount of sops changes it. The finding is the **reuse** — one value across
three services' front doors, so a compromise anywhere is a compromise
everywhere, and a rotation anywhere is a rotation everywhere.

### What this ticket is actually re-opening

[19](19-secret-hygiene-on-the-box.md) ruled this value low-value and closed with
"do not re-raise rotation as a blocker". That was a fair reading of what 19 could
see: one GUI password, on `/boot` and in Portainer. It did not know it was also
qbittorrent's and lazylibrarian's. **Whether the ruling survives the wider blast
radius is the decision** — not whether the appdata copies can be encrypted.

Bearing on it:

- The `(internal)` guard is the real boundary for all three — none is published
  ([31](31-plex-own-internet-exposure.md) is the only external route, and it is
  plex). The open question *Authentication in front of the services* in
  [open-questions.md](../open-questions.md) is the same boundary from the other
  side, and it names qbittorrent as its sharpest case.
- [24](24-migrate-download-stack.md) recorded qbittorrent's API as
  unauthenticated to everything the guard admits. A password exists — the *arr
  hold one — so either qbittorrent is bypassing auth for the bridge or 24's line
  is loose. **Establish which before deciding**, because it changes what the
  password is worth.
- Splitting the value means editing three appdata databases and one INI by hand,
  through each application's own UI, and lazylibrarian's `http_pass` is the only
  one git could plausibly own — its config is a text file, which is the
  `worth-it` question the map already carries for tautulli and bazarr.

The answer says whether the value is split, rotated, both or neither, and if
neither, what makes the guard sufficient — written so the next session does not
re-derive this from a grep.

## Answer

**Neither. The reuse is intentional and [19](19-secret-hygiene-on-the-box.md)'s
ruling stands** — rb's call, given directly: these interfaces are internally
accessible only, and convenience is worth more than distinct credentials in front
of them. Re-evaluate if that stops being true.

Opened and closed in the same session that
[41](41-orphan-unraid-templates.md) surfaced it, so it never sat on the frontier
and was never claimed.

### The trigger is already registered, and is not a new one

"If that changes" is the condition the open question *Authentication in front of
the services* already carries — **a second Service getting an external route, or
the LAN ceasing to be trusted**. This ticket adds no second trigger; it adds the
detail of what would have to be unpicked when that one fires, which is the
[open-questions.md](../open-questions.md) entry's job to point at.

### The blast radius was narrower than the grep suggested

Established before recording the ruling, because [24](24-migrate-download-stack.md)'s
"qbittorrent's API is unauthenticated to everything the guard admits" and "the
*arr hold a qbittorrent password" cannot both be the whole story. 24 was right:

```
WebUI\AuthSubnetWhitelist=172.20.0.0/16
WebUI\AuthSubnetWhitelistEnabled=true
WebUI\LocalHostAuth=false
```

and `shared` **is** `172.20.0.0/16` — the whitelist is the entire network, not a
narrower slice of it. So every container on `shared` reaches qbittorrent's WebUI
with no authentication, and the copies of the password in `sonarr.db`,
`radarr.db`, `prowlarr.db` and lazylibrarian's `qbittorrent_pass` are
**vestigial — configured, never sent**.

That leaves the shared value actually guarding two things, calibre's GUI and
lazylibrarian's `http_pass`, and it means **rotating it would not change
qbittorrent's exposure at all**. Anything that revisits this should treat
qbittorrent as a subnet-membership question rather than a password one.
