# 21 — Migrate sonarr, radarr, prowlarr and lazylibrarian

Type: task
Status: closed
Assignee: Nospamas
Resolved: 2026-08-03

## Question

Adopt the four bridge-networked, 99:100 services into git as four Stacks. They
are the uniform case: [01](01-inventory-running-containers.md) has each running
`lscr.io/linuxserver/<name>:latest` on the default bridge, already at
**99:100**, so [20](20-chown-to-99-100.md) does **not** gate them.

[08](08-deploy-homepage.md) proved the route, and it is now repetition rather
than decisions — follow
[docs/adding-a-service.md](../../../docs/adding-a-service.md), including its
two adopt-only steps: **unraid autostart off before the first deploy**, and
confirm the `/config` bind matches what is on disk.

Per service, the things this ticket must get right:

- Pin `version@digest`; every image on the box is still `latest` and months
  stale ([12](12-image-update-strategy.md)).
- Join `shared`, and keep the host port — nothing fronts these until
  [16](16-deploy-caddy.md).
- `TZ` comes from [common.env](../../../common.env) as `America/Vancouver`;
  these four currently say `America/Los_Angeles`. Same offset, so this is a
  cosmetic convergence, not a behaviour change.
- Add each name to the `BatchDeployStackIfChanged` pattern in
  [komodo/procedures.toml](../../../komodo/procedures.toml). A Stack missing
  from that list is never deployed by the loop.
- **The first Deploy of an adopted Stack is unproven** — Komodo matched the
  containers by project name but records nothing as deployed, so whether compose
  recreates or no-ops is its config-hash call. Harmless here (these four have no
  namespace-sharing sidecar), which is exactly why they should go first: they
  answer that question cheaply, before [24](24-migrate-download-stack.md) has to
  rely on it.

Homepage's widget urls for these services point at `{{HOMEPAGE_VAR_HOST}}`;
each migration can switch one to `http://<name>:<port>`.

The answer records what the first Deploy did — recreate or no-op — and whether
anything in the checklist still needed a decision.

## Resolution (2026-08-03)

**All four are Stacks, on `shared`, behind Caddy, and the loop is green.**
sonarr kept its 187 series, radarr its 1736 movies, prowlarr its 2 indexers;
lazylibrarian serves and every one of them reports only "update available" on
its health endpoint — no broken indexer, no broken download client. All four
now read `PUID=99 PGID=100 UMASK=002 TZ=America/Vancouver` where three of those
were `UMASK=022` and `America/Los_Angeles`.

### The first Deploy neither recreated nor no-opped — there was nothing to adopt

This ticket's open question was framed wrongly, and the answer matters for
[22](22-migrate-calibre.md)–[24](24-migrate-download-stack.md). These four came
from **unraid's Docker tab, not Portainer**, so they carry
`net.unraid.docker.managed=dockerman` and **no `com.docker.compose.*` labels at
all**. `project_name` has nothing to match. Compose does not adopt them, it
builds a *second* container beside each running one — and then the two fight
over the host port and the same `/config`.

So adoption here is **removal**: the container is disposable because every byte
of state is on the appdata bind, and the unraid template on `/boot` is the
rollback. That is `just adopt <container>`, gated on `--apply`, which **refuses
a container that already carries a compose project** — for those, `project_name`
really does adopt in place and removing them would destroy a running service
for nothing.

The split runs straight down the middle of the remaining migrations:

| | manager | adoption |
|---|---|---|
| sonarr, radarr, prowlarr, lazylibrarian, **calibre** | dockerMan | `just adopt`, then deploy |
| **plex**, **gluetun + qbittorrent** | Portainer/compose | `project_name` adopts in place |

[22](22-migrate-calibre.md) is the dockerMan case. [23](23-migrate-plex.md) and
[24](24-migrate-download-stack.md) are the other one, and 21 does **not** answer
whether their in-place adoption recreates or no-ops — that question survives
intact for them.

### The expensive mistake: all four went into the deploy pattern at once

One push added all four names to `BatchDeployStackIfChanged`, then only sonarr
was freed. The other three deployed against ports unraid still held, and the
batch aborted. sonarr was fine. **The three were not, and the damage was not the
failure — it was what the failure left behind.**

Docker left each container **`Up` with no published ports and no networks at
all** — `NetworkSettings.Networks` empty, nothing listening, unreachable by
container name. Then:

- `docker restart` does not repair it. The bindings are still in `HostConfig`;
  they are simply never programmed again.
- **The next reconcile reported `Execution ok`.** `DeployStackIfChanged` wants a
  changed config hash and the hash was correct all along, so the loop saw
  nothing to do and said so, over three containers serving nothing.

That is [16](16-deploy-caddy.md)'s stale-bind failure a second time, in a new
shape: **the reconcile is green and the workload is down.** Two sightings in two
sessions — added to [29](29-alerting-on-failed-reconcile.md).

The cure is recreating, which nothing in the repo could do — hence
`just redeploy <stack>`, `DestroyStack` then `DeployStack`, `--apply`-gated
because an unconditional deploy of a named Stack is precisely what the
reconcile Procedure is forbidden to do.

**Stage the pattern next time**: free the container, add *its* name, deploy,
verify, then the next.

### Decisions the checklist did not cover

- **Pinned to the build already running**, not to current. Each tag resolves to
  the exact digest on the box (`4.0.16.2944-ls298`, `6.0.4.10291-ls288`,
  `2.3.0.5236-ls133`, `ef1f6e73-ls222`), so the image was a genuine no-op and
  adoption changed one thing at a time. All three *arr now report an update
  available; Renovate raises those on its own schedule, which is the whole point
  of [12](12-image-update-strategy.md).
- **Host ports kept, all four.** Not inertia: prowlarr addresses sonarr and
  radarr as `http://192.168.1.195:8989`/`:7878`, and the indexers it writes into
  them point back at `http://192.168.1.195:9696`. That config lives in prowlarr's
  appdata, which git does not own. Dropping the ports without moving those URLs
  first breaks search silently — [30](30-arr-urls-on-shared.md).
- **Container names are `<stack>-<service>-1`**, so homepage's `container:` keys
  changed with the migration. Its widget urls are now `http://sonarr:8989` and
  its hrefs `https://sonarr.rbrb.in`.

[docs/adding-a-service.md](../../../docs/adding-a-service.md) gained step 5b and
a way to read the project name off the box;
[docs/conventions.md](../../../docs/conventions.md) gained the dockerMan rule
and both recipes.
