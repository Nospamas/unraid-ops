# 15 — Move the Unraid Web GUI off ports 80/443

Type: task (HITL)
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03

## Question

Surfaced by [04](04-reverse-proxy-and-domain.md). Unraid's own nginx holds host
ports **80 and 443** by default, so Caddy cannot bind them while the GUI is
where it is. The human chose to move the GUI rather than give Caddy its own LAN
IP on `br0` — macvlan and ipvlan both isolate the container from the host, which
would have stopped Caddy reaching the bridge-network services at
`192.168.1.195:<port>`.

Note [01](01-inventory-running-containers.md) never captured host listening
sockets, so **confirm what actually holds 80/443 before changing anything** —
the default is assumed, not observed.

Do:

- Confirm the current state: what is listening on 80 and 443 on the host, and
  whether Unraid's SSL is on or off (it decides whether 443 is even in use).
- **Settings → Management Access**: HTTP port `80` → `8008`, HTTPS port `443` →
  `8443`.
- Re-establish access on the new port and confirm the GUI still answers over
  **tailscale** as well as the LAN — the human's only path to the box is the Web
  UI over tailscale, so getting this wrong is the one change here that can lock
  them out.
- Confirm 80 and 443 are now free.

**Small but not safe**: this is the one ticket that can cost access to the box.
Do it while the tailscale path is known-good, and know the new URL before
saving.

**HITL**: box change, human-driven, per the map's Box access note.

Blocks [16](16-deploy-caddy.md) — Caddy cannot bind 80/443 until this is done.
Independent of everything else, so it can run whenever.

## Resolution (2026-08-03)

**The GUI is on `8008`, 80 and 443 are free on every interface, and a container
has been shown to take both.** The human drove the change in Settings →
Management Access; everything else here was verified over SSH.

**The ticket was right to say "confirm before changing anything", and the
observation changed the risk.** What nginx actually held:

| | addresses bound | remotely reachable |
|---|---|---|
| `:80` | `192.168.1.195`, `100.126.56.26`, tailscale v6, `127.0.0.1`, `[::1]` | **yes — the lifeline** |
| `:443` | `127.0.0.1`, `[::1]` only | no |

`USE_SSL="no"`, so **443 was never externally bound** — the map's Box access
note had this right. It still had to move: Caddy publishes `0.0.0.0:443`, and on
Linux a wildcard bind collides with a listening `127.0.0.1:443` regardless of
`SO_REUSEADDR`. So the change is one lifeline port plus one bookkeeping port,
not two lifelines.

**The ports are the ones this ticket asked for.** The HTTPS port first landed as
`4443` — harmless, since `USE_SSL="no"` means nothing external reaches it — and
the human corrected it to `8443` in the same session, so no deviation survives.
Final state in both `/boot/config/ident.cfg` and emhttpd's
`/var/local/emhttp/var.ini`: `PORT="8008"`, `PORTSSL="8443"`, `USE_SSL="no"`,
`USE_SSH="yes"`. Re-verified after the correction: nginx rebound on 8443, and 80
and 443 stayed free throughout.

**There is a CLI path, and it is the same code path as the button.**
`/etc/rc.d/rc.nginx` sources `ident.cfg` directly and regenerates
`/etc/nginx/conf.d/servers.conf` from `$PORT`/`$PORTSSL`; the GUI's Apply POSTs
`changePorts=Apply` to emhttpd's unix socket, and `/usr/local/sbin/emcmd` posts
to that identical socket. So the whole change is available headless:

```sh
emcmd 'changePorts=Apply&USE_SSL=no&PORT=8008&PORTSSL=8443&USE_TELNET=no&PORTTELNET=23&USE_SSH=yes&PORTSSH=22'
```

**Pass every field, not just the two being changed** — the GUI form submits the
whole set, emhttpd's handler is a binary that cannot be read, and a dropped
`USE_SSH=yes` is the one omission that costs the lifeline. That command was
offered and the human chose the GUI instead.

**It did not stay a one-off.** At the human's ask it became
[scripts/host.sh](../../../scripts/host.sh) behind `just host-ports` and
`just host-check` — **`host-ports` is dry-run by default**, printing the fields
that differ and the exact `emcmd` it would send, and needing `--apply` to do
anything. Also the human's ask, and generalised to every mutating recipe in
[27](27-recipe-safety-convention.md). With `/boot/config/ident.cfg` snapshotted to
[bootstrap/host/ident.cfg](../../../bootstrap/host/ident.cfg) — the map's
standing rule that a box change is a committed recipe, not an API call someone
remembers. **Only the Management Access fields are ever applied**; the other 29
settings in that file are recorded for a rebuild to copy by hand, not owned. The
wider question of how much host state git *should* own is
[26](26-host-state-scope.md), not this ticket.

Three things the build turned up, none of them guessable:

- **`ident.cfg` is CRLF.** `rc.nginx` pipes it through `fromdos` for exactly
  this reason. The field parser anchored on `"$` and matched nothing; the
  script's own validation caught it rather than a malformed `emcmd` reaching
  the box.
- **`.gitattributes` said `* text=auto eol=lf`**, which would have normalised
  the snapshot to LF on commit and made `host-check` diff against the box
  forever. `bootstrap/host/ident.cfg -text` exempts it.
- **Values are validated as bare alphanumerics** before they are interpolated
  into a single-quoted remote command, which closes the injection the query
  string would otherwise be.

Verified against the live box three ways: an apply with the snapshot already
matching (identical values reapplied, GUI still `200` on 8008, 80 and 443 still
free), a dry run with the snapshot deliberately set to `PORT=8009` (delta
reported, command printed, **box unmoved**), and the no-op case (`already matches
the snapshot -- nothing to do`). `host-check` clean and `just lint` green
throughout.

**Rollback was real, not notional**: `/boot/config/ident.cfg` was copied to
`/boot/config/ident.cfg.bak-15` first, and `rc.nginx reload` reads that file
without needing emhttpd healthy. **SSH is what made this ordinary.** The ticket
was written when the Web UI was the only way in, so moving the GUI's port meant
betting the only lifeline on one save. sshd is a separate process on `:22`
across LAN and tailnet and is untouched by anything nginx does — so the
dangerous change now has an independent path to undo it. This is the first
ticket to actually cash in the map's superseded Box access note.

**Verified after the change**, all over SSH from a laptop on the tailnet:

- `ident.cfg` and `var.ini` agree — no half-state between flash and emhttpd.
- `ss -tlnp` finds **nothing at all on 80 or 443**, on any interface.
- `http://100.126.56.26:8008/login` → `200`. The LAN address is unreachable from
  the laptop (tailnet only), so `192.168.1.195:8008` is confirmed by the bound
  socket and the human's browser, not by a request from here.
- sshd still on `:22`, LAN + tailnet.

**The blocker is proven removed, not inferred.** A throwaway container published
`-p 80:80 -p 443:443` and both bound (`0.0.0.0` and `[::]`, via `docker-proxy`);
it was removed and the ports went free again. A free port in `ss` is not the
same claim as Docker being able to take it, and 16 depends on the second one.

**One thing 16 inherits**: delete `/boot/config/ident.cfg.bak-15` once Caddy is
up. It is deliberately left until then — the window where someone might want the
GUI back on 80 in a hurry is 16 itself.

**Rebuild story amended.** These ports are host state outside git, and a fresh
flash config puts nginx back on 80/443 where Caddy cannot bind — so
[bootstrap/README.md](../../../bootstrap/README.md) now names them under
*Rebuilding the box*. No new secrets, and nothing in the repo changed but that
one paragraph.
