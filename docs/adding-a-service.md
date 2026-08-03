# Adding a service

The routine. If a step here needs a decision, the conventions are wrong — raise
it against [conventions.md](conventions.md) rather than deciding it in the
moment.

Two flavours: **new** and **adopting** (a container already runs and its appdata
must survive). The steps are the same; adopting adds three, marked **[adopt]**.

---

## 1. Make the directory

```
stacks/<name>/
  komodo.toml
  compose.yaml
```

`<name>` is the Stack name, the compose project name, and the appdata directory
name. Keep them the same unless the box already disagrees — see step 3.

## 2. Write `compose.yaml`

```yaml
services:
  <name>:
    image: <registry>/<image>:<version>@sha256:<digest>
    restart: unless-stopped
    environment:
      PUID: ${PUID}
      PGID: ${PGID}
      UMASK: ${UMASK}
      TZ: ${TZ}
    volumes:
      - ${APPDATA}/<name>:/config
    networks:
      - shared
    labels:
      caddy: <name>.rbrb.in
      caddy.import: internal
      caddy.reverse_proxy: "{{upstreams <port>}}"

networks:
  shared:
    external: true
```

- **The tag carries a version *and* a digest.**
- **`caddy.import: internal` is not optional** — `scripts/check-exposure.sh`
  fails without it. A service meant to face the internet says `x-published: true`
  on the Service instead.
- **Only declare a host port if something must reach the container without going
  through Caddy.** Otherwise the label is the entire access story.

## 3. Write `komodo.toml`

```toml
[[stack]]
name = "<name>"
[stack.config]
server = "tower"
repo = "<the repo>"
run_directory = "stacks/<name>"
project_name = "<name>"
additional_env_files = ["../../common.env"]
pre_deploy.command = """
docker network inspect shared >/dev/null 2>&1 || docker network create shared
"""
```

**[adopt]** Read the existing project name off the box first — do not assume it
matches `<name>`. A wrong `project_name` makes Komodo create a second copy
alongside the running container instead of taking it over.

## 4. Secrets, if it has any

```bash
just secret <name>
```

Opens `$EDITOR` on `stacks/<name>/secrets.sops.env`, creating it if absent, and
writes it back encrypted. Plaintext never touches the repo — do not encrypt a
file you wrote first, and `sops --encrypt` on a path outside the Stack directory
finds no creation rule at all. No `.sops.yaml` edit is needed.

Append the decrypt to `pre_deploy`:

```toml
sops -d secrets.sops.env > secrets.env
```

and read it in `compose.yaml`, **not** via `additional_env_files`:

```yaml
env_file:
  - path: secrets.env
    required: false
```

## 4b. Config files, if git owns any

If the service reads its own settings out of the repo, list them — otherwise a
push that edits one is invisible to the loop, which tracks only the compose file:

```toml
config_files = [
  { path = "config/services.yaml", requires = "restart" },
]
```

## 5. **[adopt]** Turn off unraid's autostart

In the Docker tab, autostart **off** for this container, *before* the first
deploy. Unraid's autostart is keyed by container name, so leaving it on means
unraid and compose both try to own the container.

## 6. **[adopt]** Check the appdata still fits

Confirm the uid/gid and the `/config` bind match what is already on disk — a
service that starts with the wrong PUID writes a second config tree and looks
like data loss.

Every Stack takes 99:100 from [common.env](../common.env). Plex and gluetun ran
as 1000:1000 and qbittorrent as 1001:1001, so **their appdata is only compatible
once the chown in [ticket 20](../.scratch/unraid-gitops/issues/20-chown-to-99-100.md)
has run.**

## 7. Deploy

Add the Stack's name to the `BatchDeployStackIfChanged` pattern in
[komodo/procedures.toml](../komodo/procedures.toml) — the list is explicit, and a
Stack missing from it is never deployed. Then commit and push. The Procedure
picks it up within 15 minutes, or `just reconcile` for the first deploy.

## 8. Check it

```bash
just lint             # exposure, compose, shell, Dockerfiles
just verify-secrets   # every *.sops.env still decrypts
```

- `https://<name>.rbrb.in` answers from the LAN and the tailnet, and nowhere else.
- **[adopt]** the service's own settings survived — indexers, libraries, history.

---

## Traps

- **Never bind `/etc/localtime`.** runc under Docker 29.5.3 refuses to mount onto
  it — the path is a symlink inside most images — and the container will not
  start: `not a directory: Are you trying to mount a directory onto a file?`. It
  cost plex an outage after the 7.3.2 upgrade. Old unraid templates offer it;
  `TZ` in `common.env` already does the job.
- **qbittorrent's labels live on gluetun.** It has no network identity of its
  own; the *arr address it as `http://gluetun:30024`.
- **gluetun and qbittorrent deploy together, always.** Recreating gluetun alone
  leaves qbittorrent in a dead namespace with no error.
- **plex** needs `/dev/dri` passthrough and a pinned `VERSION`, and its appdata
  is `${APPDATA}/plexmediaserver`. Dropping to uid 99 can cost hardware
  transcoding, since `/dev/dri` access is group-dependent — after the first
  deploy, play something that transcodes and confirm the dashboard still says
  `(hw)`. If it does not, that is a group problem, not a reason to restore its
  old uid.
- **calibre** binds `${MEDIA}/books` → `/config/Calibre Library`. The space in
  that path is real.
- **homepage** is the one service whose config git owns outright. `/app/config`
  must be **writable** — it seeds missing skeleton files at boot and serves HTTP
  500 if it cannot. The repo ships the complete skeleton so nothing is seeded
  untracked into the clone; logs go to `${APPDATA}/homepage/logs`.
- **CoreDNS** binds an explicit host address, `100.126.56.26:53`, not a port on
  every interface.
