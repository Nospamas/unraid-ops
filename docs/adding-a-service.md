# Adding a service

The routine. If a step here needs a decision, the layout is wrong — raise it
against [repo-layout.md](repo-layout.md) rather than deciding it in the moment.

Two flavours: **new** (nothing on the box yet) and **adopting** (a container is
already running and its appdata must survive). The steps are the same; adopting
adds three, marked **[adopt]**.

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

- **The tag carries a version and a digest.** Both. See repo-layout.
- **`caddy.import: internal` is not optional.** Leaving it off is what
  `scripts/check-exposure.sh` exists to catch. A service meant to face the
  internet says `x-published: true` on the Service instead, and that line is the
  whole point.
- **Only declare a host port if something must reach it without going through
  Caddy.** Otherwise the label is the entire access story.

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

**[adopt]** `project_name` must match what the container already belongs to, or
Komodo creates a second copy alongside the running one instead of taking it
over. For the three Portainer stacks, read the existing project name off the box
first — do not assume it matches `<name>`.

## 4. Secrets, if it has any

Most services don't. If it does:

```bash
just secret <name>
```

This opens `$EDITOR` on `stacks/<name>/secrets.sops.env`, creating it if it does
not exist, and writes it back encrypted. Plaintext never touches the repo — do
not encrypt a file you wrote first, and note that `sops --encrypt` on a path
outside the Stack directory finds no creation rule at all.

Then append the decrypt to `pre_deploy`:

```toml
pre_deploy.command = """
docker network inspect shared >/dev/null 2>&1 || docker network create shared
sops -d secrets.sops.env > secrets.env
"""
```

and read it in `compose.yaml`, **not** via `additional_env_files`:

```yaml
env_file:
  - path: secrets.env
    required: false
```

`additional_env_files` entries are tracked by default — Komodo would diff
`secrets.env` against a repo it is deliberately absent from. Only add it there
if compose must *interpolate* a secret, and then as
`{ path = "secrets.env", track = false }`.

No `.sops.yaml` edit is needed — the root rule already matches `*.sops.env`.

## 4b. Config files, if git owns any

If the service reads its own settings out of the repo, list them in
`komodo.toml` — otherwise a push that edits one is invisible to the reconcile
loop, which diffs tracked files and tracks only the compose file:

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

The container this repo produces must accept the appdata the old one wrote.
Before deploying, confirm the uid/gid and the `/config` bind match what is
already on disk — a service that starts with the wrong PUID writes a second
config tree and looks like data loss.

Every Stack takes its uid from [common.env](../common.env), which is 99:100 for
all of them. Three services used to run as something else — plex and gluetun as
1000:1000, qbittorrent as 1001:1001 — so their appdata is only compatible once
the chown in
[ticket 20](../.scratch/unraid-gitops/issues/20-chown-to-99-100.md) has run.
Adopting one of those three before 20 is done means it cannot read its own
config.

## 7. Deploy

Add the Stack's name to the `BatchDeployStackIfChanged` pattern in
[komodo/procedures.toml](../komodo/procedures.toml) — the list is explicit, and
a Stack missing from it is never deployed by the loop. Then commit and push. The
Procedure picks it up within 15 minutes, or run it by hand for the first deploy.

## 8. Check it

```bash
just lint             # exposure, compose, shell, Dockerfiles
just verify-secrets   # every *.sops.env still decrypts
```

- `https://<name>.rbrb.in` resolves and answers from the LAN and from the
  tailnet, and nowhere else.
- **[adopt]** the service's own settings survived — its indexers, libraries and
  history are where they were.

---

## Exceptions worth knowing before you hit them

- **Never bind `/etc/localtime`.** Old unraid templates and upstream examples
  offer it as the way to sync container time; on this box it is fatal. runc
  under Docker 29.5.3 refuses to mount onto that destination — the path is a
  symlink inside most images — and the container will not start:
  `not a directory: Are you trying to mount a directory onto a file?`. It cost
  plex an outage after the 7.3.2 upgrade. `TZ` in `common.env` already does the
  job.
- **qbittorrent's labels live on gluetun.** It has no network identity of its
  own. Anything addressed at it is addressed at `gluetun` — the *arr use
  `http://gluetun:30024`.
- **gluetun and qbittorrent deploy together, always.** Recreating gluetun alone
  leaves qbittorrent in a dead namespace with no error. That is why they are one
  Stack.
- **plex** needs `/dev/dri` passthrough and a pinned `VERSION`, and its appdata
  is `${APPDATA}/plexmediaserver`. It also drops from uid 1000 to 99, and
  `/dev/dri` access depends on the container user's groups — so after the first
  deploy, play something that transcodes and confirm the dashboard still says
  `(hw)`. If it does not, that is a group problem, not a reason to give plex its
  old uid back.
- **calibre** binds `${MEDIA}/books` → `/config/Calibre Library`. The space in
  that path is real.
- **homepage** is the one service whose own config git owns outright — it is
  files, not a database. `/app/config` must be **writable**: homepage seeds any
  missing skeleton file at boot and serves HTTP 500 if it cannot write. The repo
  ships the complete skeleton so nothing is ever seeded untracked into the
  clone, and logs go to `${APPDATA}/homepage/logs` to keep them out of it.
- **CoreDNS** binds an explicit host address, `100.126.56.26:53`, not a port on
  every interface.
