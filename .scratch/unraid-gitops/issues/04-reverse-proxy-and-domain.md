# 04 — Choose the reverse proxy and the domain

Type: grilling
Status: open

## Question

Services will be reached by hostname, not `IP:port`. Settle:

- **Which proxy** — SWAG, Traefik, Caddy, or nginx-proxy-manager. The deciding
  axis is configuration style: Traefik and Caddy take container labels, which
  fits a git-owned compose file well; SWAG and NPM keep their own config, which
  is more state living outside the repo.
- **Which domain**, and who hosts its DNS. This site shares nothing with
  home-ops, so `xgy.im` is not available — this is a fresh name.
- **Certificates** — DNS-01 against the domain's provider, or HTTP-01. DNS-01 is
  the only option if nothing is exposed to the internet.
- **Internal vs external hostnames** — whether a service resolves to the same
  name inside and outside the house, or split-horizon DNS is in play.

The answer names the proxy, the domain, the DNS provider and the cert method.
