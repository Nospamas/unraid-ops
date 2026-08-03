# 14 — Set up the rbrb.in zone on Cloudflare and mint the DNS token

Type: task (HITL)
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03

## Question

Nothing to decide — [04](04-reverse-proxy-and-domain.md) settled the shape. This
is the clicking that has to happen before a certificate can be issued or a
hostname can resolve.

`rbrb.in` is registered at **Gandi** and is in flight at the time of writing.
DNS moves to **Cloudflare**; the registrar stays Gandi.

Do:

- **Add `rbrb.in` as a zone in Cloudflare** and take the two assigned
  nameservers.
- **Delegate at Gandi** — point the domain's nameservers at Cloudflare's, then
  wait for the zone to go active. This is the only step with a propagation wait
  in it.
- **Create the wildcard record**: `*.rbrb.in` → **A `192.168.1.195`**, and set
  it **DNS-only (grey cloud)**. Cloudflare will not proxy a private address, and
  an orange cloud here silently breaks everything.
- **Mint a scoped API token** — permission `Zone / DNS / Edit`, resources
  limited to the `rbrb.in` zone only. Not the Global API Key, and not
  account-wide. This is what solves the DNS-01 challenge.

The token is the **sixth live secret**, joining the five
[03](03-secrets-handling.md) settled. It goes into the SOPS-encrypted
`secrets.sops.env` for the Caddy stack, per 03's mechanism — so this ticket ends
by handing the token over for encryption, not by pasting it anywhere in the
repo.

**HITL**: all of this is web UI work in two vendor consoles, and it produces a
credential. The human does it; the session writes the checklist and takes back
the zone status and the token.

The checklist is [assets/14-cloudflare-checklist.md](../assets/14-cloudflare-checklist.md).
It corrects two things this ticket got wrong, both verified before it was
written:

- **The zone is not blank.** Gandi's defaults are live — apex `A`, `www` CNAME,
  `MX`, SPF `TXT` — and Cloudflare imports them on the scan. Ruled: delete all
  four. The apex `A` would otherwise beat the wildcard for bare `rbrb.in`.
- **`Zone / DNS / Edit` alone is not enough.** `libdns/cloudflare` resolves the
  zone ID via `GET /zones?name=`, so **`Zone / Zone / Read`** is required too.
  Cloudflare's "Edit zone DNS" template grants exactly the pair.

Resolved when the zone is active, the wildcard resolves to `192.168.1.195` from
the LAN, and the token exists and is encrypted.

## Resolution (2026-08-03)

**All three conditions met and verified against Cloudflare's API, not the UI.**
The zone is active on `corey.ns.cloudflare.com` / `pearl.ns.cloudflare.com`; the
registrar stays Gandi, as decided. `*.rbrb.in` → A `192.168.1.195`,
`proxied: false` — the grey cloud held, and an arbitrary hostname answers
`192.168.1.195` from the authoritative nameserver.

**The token is the sixth live secret**, encrypted at
[stacks/caddy/secrets.sops.env](../../../stacks/caddy/secrets.sops.env) as
`CLOUDFLARE_API_TOKEN`. It is user-scoped, minted from the **"Edit zone DNS"
template**, Zone Resources limited to `rbrb.in`. Verified three ways:
`/user/tokens/verify` returns `active`; `GET /zones` returns **exactly one**
zone, which proves the scoping is real and not All-zones; and
`GET /zones?name=rbrb.in` **succeeds**, which is the direct behavioural proof
that `Zone / Zone / Read` is present.

**This ticket's own instructions were wrong twice**, both caught before the
human touched a console:

- **`Zone / DNS / Edit` alone is not enough.** `libdns/cloudflare` — which
  `caddy-dns/cloudflare` wraps — resolves the zone ID via `GET /zones?name=`
  before it can write `_acme-challenge`, so **`Zone / Zone / Read`** is
  required. Its README asks for `Zone:Read, Zone.DNS:Write`. Had the ticket been
  followed literally, [16](16-deploy-caddy.md) would have failed at zone lookup,
  *before* attempting a record — an error that reads like a Caddy fault, not a
  token fault. Cloudflare's template grants the pair; **scoping Zone:Read to the
  single zone works**, despite the README saying "All zones".
- **The zone was not blank.** Gandi's fresh-domain defaults were live and
  Cloudflare imported them on the scan — apex `A` → its web-redirect IP, `www`
  CNAME, `MX`, SPF `TXT`, five mail `SRV`, and a `webmail` CNAME. Two of them
  came back **orange-clouded**.

**Deviation from the ruling, and it stands**: the ruling was delete all four.
The human deleted the apex `A` and the `www` CNAME, and **kept the Gandi mail
set** — `MX` ×2, SPF `TXT`, the five `SRV`, and `webmail.rbrb.in`. Mail on
`rbrb.in` therefore keeps working, and nothing in this map is affected.

**Two facts [16](16-deploy-caddy.md) needs:**

- **`webmail.rbrb.in` is a reserved hostname.** It is a real, *proxied* record,
  so it does **not** fall through the wildcard — it resolves to Cloudflare's
  anycast IPs, not the box. Caddy can never own that name.
- **The apex has no `A` record at all.** A DNS wildcard never covers the apex,
  so bare `rbrb.in` does not resolve. Fine today — every service is
  `<name>.rbrb.in` — but if anything ever wants the apex it needs its own
  record, and that is a `192.168.1.195` grey-cloud A, not a wildcard change.

**Housekeeping.** The key was handed over as `DNS_ZONE_TOKEN` and **renamed to
`CLOUDFLARE_API_TOKEN`**, which is what this ticket and the checklist both
committed to and what upstream examples use — a mismatch here would have
surfaced in 16 as a Caddyfile that reads an unset variable. The plaintext
arrived **untracked** and was encrypted in place, so it never entered git and
nothing reached the public repo. `stacks/caddy/` now exists holding *only* the
secret; 16 fills in `compose.yaml` and `komodo.toml`. `just lint` tolerates a
Stack directory with no compose file (both loops are `nullglob`-guarded), and
`just verify-secrets` passes on all three encrypted files.
