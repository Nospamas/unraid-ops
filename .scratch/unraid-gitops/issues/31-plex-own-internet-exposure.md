# 31 — Decide what the repo says about plex's own internet exposure

Type: grilling
Status: closed
Assignee: Nospamas
Resolved: 2026-08-05

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

## Resolution (2026-08-05)

**The two keys were never asking the same question, and forcing them to was the
bug.** `caddy.import` governs the Caddy route and is the label that does the
work; `x-published` says the Service is on the internet, by whatever path, and
now carries prose naming that path. `check-exposure.sh` drops the
mutual-exclusion FAIL — it asserts a fronted Service carries **at least one** —
and walks every Service rather than only the fronted ones, because being
published is a property of the Service. Plex carries both, is the repo's one
published Service, and `grep -rn x-published stacks/` is finally true.

The value could not stay `true`: the check tested that literal, and `true` says
nothing about the mechanism — which for plex is a router this repo does not own,
the exact fact that hid the exposure.

**Dropping `caddy.import: internal` was never an option, and the ticket did not
say why.** `x-published` is inert, a marker key only. `caddy.import` is what
imports the guard snippet, so satisfying the old lint by deleting it would have
opened `plex.rbrb.in` to the world — a lint fix that published a service.

### The auth bullet: premise corrected, ruling stands

Measured rather than assumed: plex's Preferences carry
`allowedNetworks="192.168.1.0/24"`, so **the internet path is authenticated** —
a WAN client is outside that range and gets plex's account auth. `/identity`
answering unauthenticated is by design and carries no library data.

The exemption grants **strictly less than the repo already does**. [30]
established that a LAN browser arrives at a Caddy-fronted service from
`172.20.0.1`, so the `(internal)` guard admits all of `192.168.1.0/24` to every
service with no auth at all. Plex matches the existing posture rather than
widening it.

So the fog's trigger is not "a service is published" but **a *second* service
with an external route** — and plex would not join that scheme anyway, since it
does not sit behind forward-auth or OAuth.

### The third bullet: `just ports-audit`

Built, because 30's evidence is that the prose is what decayed. Lint keeps
asserting the sentence exists; `scripts/ports.sh` asks the box who dials each
declared port. Two sources, neither sufficient alone:

- **`nat DOCKER` packet counters** — cumulative since the container started, so
  "nothing has *ever* dialled this" is answerable. This is the one 30 needed.
- **`ss` established** — says who, but only right now.

**The counter is structurally blind to a `127.0.0.1` bind**, found while
building it: `nat OUTPUT` jumps to `DOCKER` only for `! 127.0.0.0/8`, so
docker-proxy serves loopback in userland and `30024`'s counter reads **0** while
gatus probes it every 60s. Printing that 0 would have shipped exactly this
ticket's own failure — a check blind without saying so. It reports the blind
spot instead.

First run: `32400` 972 packets, CoreDNS `53/udp` 47373, ntfy `8095` 235, the
three loopback ports blind. No claim looks decayed.

### Checked, not changed

Raised mid-session: should gatus probe through Caddy rather than at containers?
**It already does** — every `services` probe is `https://<name>.rbrb.in/` and
[stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml) says so
in its header. The three direct probes are `127.0.0.1:30024/30025/30026`, which
assert body values Caddy never surfaces (exit IP, bound address) and are the
only thing that sees a dead tunnel — `https://qbittorrent.rbrb.in/` answered 200
throughout a real VPN outage, served from inside the namespace. No ticket.

### Not reopened

**The forward stays**, per this ticket's own first bullet. Nothing here touches
80/443, the GUI or tailscale.
