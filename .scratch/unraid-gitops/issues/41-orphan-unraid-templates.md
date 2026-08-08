---
id: "41"
title: Dispose of the five orphan Unraid templates
type: task
status: open
description: >
  Five orphan Unraid templates on `/boot` still name the *arr by their bare
  container names, so recreating one from the Docker tab starts a second
  container competing over the same appdata. Decide whether that pre-migration
  record is worth keeping.
touches: []
---

# 41 — Dispose of the five orphan Unraid templates

Blocked by: —
Claimed by: wayfinder session, 2026-08-07

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
