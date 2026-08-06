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

- ~~**Does the forward stay?**~~ **Answered: it stays.** 32400 is the intended
  port, deliberately forwarded, and remote clients get a **direct** connection
  rather than falling back to Plex Relay — which is the whole point, since Relay
  caps throughput and direct does not. `ManualPortMappingMode="1"` is the same
  decision from plex's side: a static forward instead of asking the router for
  one over UPnP. Split-horizon ([17](17-deploy-coredns.md),
  [18](18-tailnet-split-dns.md)) does not replace it — the tailnet does not
  reach the people this serves.

  So this ticket is **not** about closing a hole. It is about the repo
  describing, in the file that governs plex, an exposure that is deliberate.
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

## Added by [30](30-arr-urls-on-shared.md)

**Evidence for the third bullet.** 30 found *two* false `x-host-port` values —
both written by the ticket that opened the port, both true then. Acting on one
would have silently deleted [06](06-qbittorrent-vpn-topology.md)'s
tunnel-binding probe. So the comment convention is not the weaker version of the
check; it is the thing that decayed. Weigh a check that can **find** the reader
against one that asserts a sentence exists.

30 also narrows the surface: **plex's `32400` is now the only host port a LAN
browser could hit.** CoreDNS and ntfy bind explicit addresses, gatus and Komodo
are the Caddy-repair carve-out, and `30024` went to loopback.
