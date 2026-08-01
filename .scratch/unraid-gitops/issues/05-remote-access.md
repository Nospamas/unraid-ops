# 05 — Decide the remote access approach

Type: grilling
Status: open
Blocked by: 04

## Question

How do you reach the stack from outside the house?

- **Tailscale** — no open ports, but every client needs the tailnet, and
  hostnames need to resolve on it.
- **Cloudflare tunnel** — no open ports, public hostnames, but Cloudflare
  terminates TLS and its ToS restrict proxying large media streams.
- **Forwarded ports** — direct, requires a static or dynamic-DNS'd WAN address
  and puts the proxy on the public internet.

Resolve alongside it: whether *every* service is remotely reachable or only
some (qbittorrent's UI and the *arr admin surfaces are the sensitive ones), and
whether authentication sits in front of them.

Depends on ticket 04 because the proxy and cert choice constrain what can front
a tunnel or a tailnet.
