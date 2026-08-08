---
id: "41"
title: Dispose of the five orphan Unraid templates
type: task
status: closed
description: >
  All ten files gone. The record was redundant with git down to
  lazylibrarian's `DOCKER_MODS`, and it was never a rollback — but this
  ticket's "hold no secrets" was wrong: `my-calibre.xml` and its `.bak-19`
  held the live GUI password cleartext, and it is reused.
touches: [docs/adding-a-service.md]
---

# 41 — Dispose of the five orphan Unraid templates

Resolved: 2026-08-07
Blocked by: —

## Question

Surfaced by [25](25-retire-portainer.md), which emptied Unraid's Docker tab of
containers and left this behind.
`/boot/config/plugins/dockerMan/templates-user/` still holds five templates for
services git now owns:

```
my-sonarr.xml  my-radarr.xml  my-prowlarr.xml  my-calibre.xml  my-lazylibrarian.xml
```

each with a `.bak-19` copy from [19](19-secret-hygiene-on-the-box.md)'s sweep.
The `.bak-19` copies differ from the live ones only in `UMASK` `022`→`002`
([20](20-chown-to-99-100.md)) and hold no secrets — checked.

**The hazard is a duplicate, not a leak.** Each template names its container by
the bare service name — `sonarr` — while the Stack from
[21](21-migrate-arr-stacks.md) runs `sonarr-sonarr-1`. Nothing stops the two
coexisting, so recreating one from the Docker tab starts a **second** container
on the same appdata, competing with the Komodo Stack over the same database. The
name collision that would have made it fail loudly is exactly the one that does
not happen.

This is [25](25-retire-portainer.md)'s disposal question a second time: these
templates are the pre-migration run configuration for the five services
[21](21-migrate-arr-stacks.md) and [22](22-migrate-calibre.md) adopted, the same
way Portainer's compose was for plex and the download pair. Decide whether that
record is worth keeping now that git holds the running definitions — and if it
is not, whether deleting the files is enough or Unraid caches them elsewhere.

Note that the templates are on `/boot`, the USB flash drive, not appdata.

## Answer

**All ten files deleted.** `templates-user/` is empty. Same ruling as
[25](25-retire-portainer.md), for the same reason and one this ticket did not
know about.

### The record was already in git, down to the last variable

Diffed every template against the Stack that replaced it. Repository, WebUI
port, appdata and media binds, `PUID`/`PGID`/`UMASK`, and lazylibrarian's
`DOCKER_MODS: linuxserver/mods:universal-calibre` — all of it is in
[stacks/](../../../stacks/). `<ExtraParams>` and `<PostArgs>` were empty in all
five. What the XML held and git does not: `DateInstalled`, linuxserver's
category and marketing blurb, and calibre's three host ports, which
[22](22-migrate-calibre.md) deliberately does not publish and says so.

**And it was never a rollback.** [21](21-migrate-arr-stacks.md) established the
container is disposable because the state is on the appdata bind — the template
adds nothing to that, and using it starts a second container against the same
database. The "rollback" reading was the hazard wearing a friendly name.

### This ticket's premise was wrong: the calibre password was live, and cleartext

The body above says the templates "hold no secrets — checked". That was checked
against the `.bak-19` *diff*, which is only `UMASK` `022`→`002`, and it does not
generalise. [19](19-secret-hygiene-on-the-box.md) had it right and this ticket
lost it: `my-calibre.xml` carries `PASSWORD` in cleartext, `Mask="true"` being a
UI affordance and nothing more, and the `.bak-19` carries it too. Confirmed by
hash against the running container that it is the **live** password, not a
pre-migration one — [22](22-migrate-calibre.md) carried the credentials over
unchanged.

So the deletion took two cleartext copies off the flash drive. A `grep` over
`/boot/config` now returns none.

**Rotation was offered and declined** — 19 ruled the value low-value and said
not to re-raise rotation as a blocker, and rb held that line.

### `/boot` does not ship off-site on this box

[03](03-secrets-handling.md) kept the age key off `/boot` because Unraid Connect
backs the flash drive up to Unraid's cloud, and [19](19-secret-hygiene-on-the-box.md)
attached that worry to the calibre password. **Unraid Connect is not
installed** — no `unraid.net` plugin, and the plugin list is
DiskSpaceManagement, community.applications, dynamix.system.temp, intel-gpu-top,
tailscale, unassigned.devices ×3 and zip_manager. The exposure was a USB stick
in a box behind a locked door, not a copy in someone else's storage.

### Deleting is enough — nothing caches them

The ticket's second half. `dockerMan/templates/` is empty, `template-repos` is
one URL, `/var/lib/docker/unraid-autostart` is empty, and a `grep -rl` for the
image names over all of `/boot/config` found these ten files and nothing else.
[25](25-retire-portainer.md) already proved it once by deleting
`my-PortainerCE.xml`.

**Community Applications is installed**, which the ticket did not count: its
*Previous Apps* list reads the same directory, so the template was reachable
from two places in the UI, not one.

### The routine is why five of them were sitting there

[docs/adding-a-service.md](../../../docs/adding-a-service.md) told step 5b that
the template *is* the rollback and never told anyone to dispose of it. Now step
**8b** does, after the checks in step 8 — with the reason the name collision
does not save you, and an instruction to read the file for secrets first.
Without that step this recurs on the next adopted service.

### Surfaced: the password is reused, and 19's ruling was scoped to one copy

Grepping the box for the value to confirm the flash was clean turned up more
than expected. It is **one password**, and it is:

- `stacks/calibre/secrets.sops.env` → the one `0600 secrets.env` — legitimate
- `DownloadClients` in `sonarr.db`, `radarr.db` and `prowlarr.db` — their
  qBittorrent client credential
- `lazylibrarian/config.ini` as **both** `qbittorrent_pass` and `http_pass`, its
  own UI password, plus two `.bak` copies

19 ruled "the calibre password" low-value, and that was a fair reading of one
credential in one place. It is not the same judgement as one password guarding
qBittorrent's WebUI, calibre's GUI and lazylibrarian's UI at once. Not resolved
here — ticketed as [52](52-one-password-across-four-services.md).
