# 05 — Decide the remote access approach

Type: grilling
Status: open

## Question

How do you reach the stack from outside the house?

**[04](04-reverse-proxy-and-domain.md) has resolved and narrowed this
considerably.** The human ruled that **most if not all services are internally
available only for now**, and that hostnames use single public records pointing
at local IPs — `*.rbrb.in` → A `192.168.1.195`, grey cloud. Split-horizon is
worth building on *in future* but is explicitly not being built now.

So the original framing is too broad. What actually remains:

- **The tailnet path is now broken, and that is the sharp question.** The human
  reaches the box today over tailscale (`tower` = `100.126.56.26`), but the
  wildcard points at the LAN address, which does not route over the tailnet.
  Either `tower` **advertises `192.168.1.0/24` as a subnet router**, or a
  split-horizon answer arrives earlier than planned, or the wildcard points at
  the tailscale IP instead and non-tailnet LAN devices lose access. Pick one.
- **Whether anything at all is published beyond the tailnet**, now that the
  default is LAN-only. Cloudflare tunnel and forwarded ports are still the two
  candidates if the answer is yes, but neither is needed if it is no.
- **Authentication — this ticket now owns it outright.** The map's Secret
  severity note expected 04 or 05 to settle what sits in front of calibre's
  login. 04 declined it, correctly: with everything LAN-only, nothing is on the
  internet and there is nothing to defend yet. The moment anything is published,
  the question is live here — and calibre's GUI password and qbittorrent's WebUI
  are the two surfaces that matter.

Cert issuance is **not** a constraint on any of this: 04 chose DNS-01, so
certificates never require inbound reachability.
