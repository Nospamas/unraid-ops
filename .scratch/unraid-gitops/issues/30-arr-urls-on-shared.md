# 30 — Move the *arr's in-app URLs onto `shared`, and drop the host ports

Type: task
Status: open
Blocked by: 24

## Question

Surfaced by [21](21-migrate-arr-stacks.md). The four *arr Stacks kept their host
ports — 8989, 7878, 9696, 5299 — and
[docs/conventions.md](../../../docs/conventions.md) says a host port exists only
when something must reach the container without going through Caddy. Something
does, and it is not a browser:

- prowlarr addresses sonarr and radarr as `http://192.168.1.195:8989` and
  `:7878` (its `Applications` rows)
- the indexers prowlarr *writes into* them point back at
  `http://192.168.1.195:9696` (`prowlarrUrl`)
- sonarr and radarr address qbittorrent as `192.168.1.195:30024`

Every one of those is a container-to-container path now that all of them are on
`shared`, and every one lives in **appdata that git does not own**. So this is
not a repo edit — it is app config changed through each UI or API, and then the
`ports:` blocks come out of four compose files.

Blocked by [24](24-migrate-download-stack.md): the qbittorrent leg is half the
work and gluetun holds that namespace, so doing this before the download Stack
migrates would only have to be redone.

The prize is small and real: four fewer LAN-open ports, and the `(internal)`
guard becoming the only way in rather than one of two.

**Do not do this piecemeal from a health-check warning.** A wrong URL in
prowlarr fails silently — search returns nothing and nothing logs an error.
Change the URLs first, confirm a search still returns results end to end, and
only then delete the ports.
