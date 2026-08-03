# Checklist — Cloudflare zone and DNS token for `rbrb.in`

Hand-off for [ticket 14](../issues/14-cloudflare-zone-and-token.md). Web UI work
in two vendor consoles, producing one credential. Nothing here is decided —
[04](../issues/04-reverse-proxy-and-domain.md) settled the shape.

## State before starting (verified 2026-08-02)

| fact | value |
|---|---|
| registrar | Gandi |
| nameservers | `ns-130-a`, `ns-26-b`, `ns-211-c.gandi.net` — **still Gandi** |
| apex `A` | `217.70.184.38` (Gandi web-redirect) |
| `www` | CNAME → `webredir.vip.gandi.net.` |
| `MX` | `10 spool.mail.gandi.net.`, `50 fb.mail.gandi.net.` |
| `TXT` | `v=spf1 include:_mailcust.gandi.net ?all` |
| `*.rbrb.in` | does not exist |

The zone is **not blank** — those four are Gandi's defaults for a fresh domain.
Cloudflare imports them during the zone scan. The human has ruled: **delete all
four**. The apex `A` is the one that matters — left in place it beats the
wildcard for bare `rbrb.in` and serves Gandi's parking redirect.

## 1. Add the zone at Cloudflare

- Add site `rbrb.in`, **Free** plan.
- Let the scan run, then **delete the four imported records** above. The zone
  should end holding nothing.
- Take the two assigned nameservers (`*.ns.cloudflare.com`).

## 2. Delegate at Gandi

Gandi → the domain → **Nameservers** → switch from Gandi's to **external**, and
enter the two Cloudflare names.

This is the only step with a propagation wait. Cloudflare emails when the zone
goes active; it is usually minutes, occasionally hours.

## 3. Create the wildcard

In the Cloudflare zone, **DNS → Records → Add record**:

| field | value |
|---|---|
| Type | `A` |
| Name | `*` |
| IPv4 | `192.168.1.195` |
| Proxy status | **DNS only (grey cloud)** |
| TTL | Auto |

Grey cloud is not optional — Cloudflare refuses to proxy an RFC1918 address, and
an orange cloud here breaks every hostname silently. A **grey-cloud wildcard is
free**; only a *proxied* wildcard needs Enterprise, so ignore any nudge toward
an upgrade.

## 4. Mint the token

**My Profile → API Tokens → Create Token → use the "Edit zone DNS" template.**

Use the template, do not hand-pick permissions. It grants **two**:

- `Zone / DNS / Edit` — writes the `_acme-challenge` TXT record.
- `Zone / Zone / Read` — **the one ticket 14 omitted.** `libdns/cloudflare`, which
  `caddy-dns/cloudflare` wraps, calls `GET /zones?name=rbrb.in` to resolve the
  zone ID before it can write anything. Without Zone:Read the DNS-01 challenge
  fails at lookup, before it ever attempts the record.

Then:

- **Zone Resources**: `Include → Specific zone → rbrb.in`. Not "All zones", not
  account-wide, and **not** the Global API Key.
- Leave Client IP Filtering and TTL empty.
- Copy the token — Cloudflare shows it exactly once.

> `libdns/cloudflare`'s README says "All zones" for Zone:Read because it is
> simpler advice. Scoping to the single zone works — the list-zones call returns
> whatever the token can read. If 16's first certificate fails with a
> zone-lookup error, widening Zone:Read to All zones is the known fix, and worth
> recording on 16 if it happens.

## 5. Hand the token back

Paste it into the session. It becomes the **sixth live secret**
([03](../issues/03-secrets-handling.md)) and goes straight into
SOPS — `stacks/caddy/secrets.sops.env`, as `CLOUDFLARE_API_TOKEN`. It is never
pasted into the repo in plaintext and never committed unencrypted.

## Resolved when

- Zone active at Cloudflare, `dig NS rbrb.in` returns Cloudflare nameservers.
- `dig +short anything.rbrb.in` → `192.168.1.195` from the LAN.
- Token verifies against `/user/tokens/verify`, reads the `rbrb.in` zone, and is
  encrypted in the repo.
