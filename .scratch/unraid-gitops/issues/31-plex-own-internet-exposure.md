# 31 — Decide what the repo says about plex's own internet exposure

Type: grilling
Status: open

## Question

Surfaced by [23](23-migrate-plex.md), and verified rather than suspected:
`http://75.155.182.130:32400/identity` answers from outside both networks with
this server's machineIdentifier. Plex has `PublishServerOnPlexOnlineKey="1"` and
`ManualPortMappingMode="1"` in its Preferences, and rb's router forwards 32400.
It predates this repo and nothing in this map opened it.

So **`grep -rn x-published stacks/` is wrong** when it reports that nothing
faces the internet, and [05](05-remote-access.md)'s "nothing is published" —
which the map leans on in three separate places — is wrong with it. The gap is
structural, not an oversight: `scripts/check-exposure.sh` reasons about the
**Caddy** path, and this exposure is a host port plus a router the repo does not
own.

What has to be decided:

- **Does the forward stay?** Split-horizon now reaches plex from anywhere on the
  tailnet ([17](17-deploy-coredns.md), [18](18-tailnet-split-dns.md)), so the
  forward is only load-bearing for clients that cannot run tailscale — a friend's
  Plex app, a TV at someone else's house. Whether anyone actually uses it is a
  question for the human, not the box. Closing it is a router change on **rb's**
  network, which is a hand-off either way.
- **If it stays, how does the repo record it?** `x-published: true` is the one
  grep that answers "what faces the internet" [07], and today plex says
  `caddy.import: internal`, which is true of the Caddy path and misleading about
  the service. The two are mutually exclusive by
  [check-exposure.sh](../../../scripts/check-exposure.sh), so saying both is
  currently a lint failure — that may be the wrong shape for a service exposed
  twice, by two different mechanisms.
- **Should the check see host ports at all?** It cannot see a router, but it can
  see that a Service publishes a port, and "published port + no statement about
  it" is the condition that hid this for the whole map. A weaker version: every
  host port carries a comment saying who reaches it, which
  [docs/conventions.md](../../../docs/conventions.md) already asks for in prose
  and nothing enforces.
- **What the answer means for the auth fog.** The map has said since
  [04](04-reverse-proxy-and-domain.md) that authentication can wait because
  nothing is published. For plex that premise was never true — it has account
  auth of its own and always has — but the reasoning needs correcting rather
  than quietly relying on plex being the exception.

Not a lockout risk: nothing here touches 80/443, the GUI, or tailscale.
