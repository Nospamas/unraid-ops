# Open questions

Questions no current map is finding its way to, kept so they are not re-derived
and not opened early. Each says what is open, the **trigger** that would make it
sharp enough to ticket, and where the reasoning already is.

**Deferred, not ruled out.** A question decided *against* stays in the
**Out of scope** section of the map that decided it. Nothing here has been
declined — it is all waiting on something.

## Reconciling on push rather than on a timer

Komodo supports git webhooks and Core already generates the secret, but a webhook
needs GitHub to reach Core, and Komodo is not published.
[16](issues/16-deploy-caddy.md) landed the proxy that would front it, so what is
left is the *scope* question, not a technical one.

**Sharp when** publishing Komodo is on the table. Until then 15 minutes is the
answer, not a defect.

*Raised by map 01.*

## Appdata backup and box rebuild

With definitions in git, appdata is the remaining single point of failure — 24G,
dominated by plex — and Komodo's own database is off-git state holding the
resource records. [24](issues/24-migrate-download-stack.md) found the NordVPN key
sitting in that database in plaintext, so a backup of it is a backup of a secret.

**Sharp when** anything in appdata becomes expensive to lose, or a rebuild is
actually planned rather than reasoned about.

*Raised by map 01.*

## Authentication in front of the services

Declined by [04](issues/04-reverse-proxy-and-domain.md) and
[05](issues/05-remote-access.md) on the grounds that nothing was published;
[31](issues/31-plex-own-internet-exposure.md) corrected that premise and left the
ruling standing, because plex's own account auth defends its port and
`allowedNetworks` is narrower than the `(internal)` guard.

**Sharp when** a *second* Service gets an external route, or the LAN stops being
trusted (guest wifi, IoT). qbittorrent is the sharpest case —
[24](issues/24-migrate-download-stack.md) left its API unauthenticated to
everything the guard admits, which is sound only while the guard is.

*Raised by map 01.*

## What a moved DHCP lease costs

[26](issues/26-host-state-scope.md) found `192.168.1.195` is a lease rather than
configuration, and [32](issues/32-lan-resolver.md) made rb's LAN follow the
Cloudflare record that bets on it. The mitigation is settled — the address is a
DHCP reservation — but the reservation and the record are two pieces of off-git
state that must move together, and only a human can move either.

**Sharp when** the box is re-addressed.

*Raised by map 01.*

## Home-network devices that are not on the tailnet

They have no route to tower at all, and no DNS answer can give them one — it
would take a subnet router, which [05](issues/05-remote-access.md) declined on
shadowed-route grounds.

**Sharp when** something on that network that cannot run tailscale — a TV, a
printer, a guest — actually needs a service.

*Raised by map 01.*

