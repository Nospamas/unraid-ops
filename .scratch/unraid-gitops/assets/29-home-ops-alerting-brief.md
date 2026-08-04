# Brief: the home-ops half of cross-site alerting

Hand-off from `unraid-ops` ticket [29](../issues/29-alerting-on-failed-reconcile.md).
Written for an agent working in `~/home-ops`. Nothing here changes `unraid-ops`.

## Why you are being asked

Both sites run full observability and neither one shouts. `unraid-ops` has just
fixed its half. This is yours.

Two independent problems, and the second is the reason this is cross-site at all:

1. **home-ops watches and tells nobody.** `kubernetes/apps/observability/gatus`
   has no `alerting:` block, and every line of
   `kubernetes/apps/observability/kube-prometheus-stack/app/alertmanagerconfig.yaml`
   is commented out. Prometheus fires into a void.
2. **Neither site can report its own death.** A monitoring stack hosted on the
   thing it monitors goes silent exactly when it matters, and silence is
   indistinguishable from health. The only fix is for each site to watch the
   other.

## The design, in one paragraph

Each site runs its **own** ntfy. Each site's alerting goes to its **own** ntfy.
Each site's gatus additionally probes **the other site**. The phone subscribes to
both servers. If tower dies, home-ops's gatus notices and shouts on home-ops's
ntfy; if home-ops dies, the reverse.

Note what this design deliberately avoids: **no cross-site publishing.** Neither
site needs a credential for the other, because neither one ever writes to the
other's ntfy. It only needs to be able to *reach* it. That is the whole reason
this shape was chosen over cross-publishing.

## What already exists on the tower side

Assume these are live before you probe them.

| fact | value |
|---|---|
| tower's tailnet address | `100.126.56.26` |
| tower's ntfy | `http://100.126.56.26:8095`, health at `/v1/health` |
| tower's gatus | `http://100.126.56.26:8090`, health at `/health` |
| auth on both | **none** — tailscale is the boundary, by design |
| tailnet nodes today | `tower`, `ubuntu-dev`, `earth`, `uranus` |

Both bind their ports directly and are **not** behind tower's reverse proxy.
That is deliberate and it is the one design rule worth carrying over:

> **The alert path must not traverse the thing it reports on.** Routing alerts
> through the proxy means a proxy outage silences the alert about the proxy
> outage.

Apply the same test to anything you put in front of home-ops's ntfy. If it sits
behind `envoy-external` and the Cloudflare Tunnel, then a tunnel outage takes
out both home-ops's services *and* its ability to tell you about them.

## Work items

### 1. Tailscale operator into the cluster

`grep -ril tailscale kubernetes/` currently returns nothing, so the cluster has
no path to the tailnet at all. This blocks everything else here.

The operator's **egress** mode is what this needs, not a subnet router: a
`Service` annotated with `tailscale.com/tailnet-fqdn: tower.<tailnet>.ts.net`
gets a ClusterIP that proxies to the tailnet node, and gatus then probes an
ordinary in-cluster address. Verify against current operator docs rather than
trusting this paragraph — the annotation has changed name historically.

An OAuth client for the operator is a new secret. It is the only new credential
this brief requires.

Watch the address overlap, which has already bitten `unraid-ops` once: the home
network is `192.168.0.0/16`, which **contains** rb's `192.168.1.0/24`. Do not
advertise or accept routes that would shadow the home network's own space. Egress
mode sidesteps this entirely by using tailnet addresses only, which is a second
reason to prefer it over a subnet router.

### 2. An ntfy instance in home-ops

Its own, not shared with tower. Android connects by direct WebSocket, so no
Firebase and no ntfy.sh relay — iOS is explicitly not a consideration.

Decisions to make deliberately rather than by default:

- **Reachability.** It must be reachable when the tunnel is down, per the rule
  above. A tailnet address is the natural answer, and it is also how tower will
  probe you.
- **`base-url`** must match the address the phone actually subscribes to, or
  links in notifications break.
- **`auth-default-access`** — set it explicitly. tower chose `read-write` for
  everything the tailnet admits, on the grounds that the tailnet is the trust
  boundary. Match it or diverge on purpose.
- **Persistence.** ntfy's cache is a small SQLite file; decide whether message
  history survives a restart.

### 3. Give gatus and Alertmanager somewhere to go

- gatus: add an `alerting:` block pointing at home-ops's ntfy, and attach alerts
  to the existing endpoints. The auto-discovery sidecar generates endpoints from
  HTTPRoute annotations, so check whether alert config rides along or must be
  set as a default.
- Alertmanager: the commented-out config references
  `ALERTMANAGER_PUSHOVER_TOKEN`, `PUSHOVER_USER_KEY` and
  `HEALTHCHECKS_IO_HEARTBEAT_URL`. **These are template residue — the accounts
  do not exist.** Rewrite the receivers for ntfy rather than trying to revive
  them, and drop the dead keys from `secret.sops.yaml` so the next reader is not
  misled the same way.
- The commented config's `Watchdog → heartbeat` route is worth keeping in spirit
  even so: it is a dead-man's switch, and it is the same idea as this brief, just
  aimed at a third party instead of at tower.

### 4. Probe tower

Add endpoints to home-ops's gatus. This is the item that actually closes the
blind spot, so do not let it fall off the end.

Suggested, mirroring the existing `icmp://1.1.1.1` connectivity checks:

- `icmp://100.126.56.26` — tower reachable at all
- `http://100.126.56.26:8090/health` — tower's gatus alive
- `http://100.126.56.26:8095/v1/health` — tower's ntfy alive

Give these a **longer failure threshold than the local checks**. A tailnet path
between two sites crosses the open internet, so a transient WAN blip is not
tower dying and should not read as it. tower uses 60s interval and 3 consecutive
failures for its own local probes; something more forgiving is right here.

Alert these to home-ops's own ntfy. That is the entire point — the alert about
tower must not originate on tower.

## What tower does once you are done

tower's gatus adds the mirror-image probes against home-ops. That work is
tracked on the `unraid-ops` map and is **not** yours. Tell the human when home-ops
is tailnet-reachable and what addresses to probe, and that side gets picked up
there.

## Scope

Everything above is home-ops work in the home-ops repo. `unraid-ops`'s map
records this as an open dependency and does not consider its own box-down gap
closed until item 4 exists.
