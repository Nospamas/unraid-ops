# 14 — Set up the rbrb.in zone on Cloudflare and mint the DNS token

Type: task (HITL)
Status: open
Assignee: Nospamas

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
