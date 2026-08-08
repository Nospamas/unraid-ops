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
  fails without it, and it is the label that imports the guard. A service that is
  on the internet by *any* path adds `x-published: <how>` on the Service; that is
  a second statement, not a replacement for the guard.
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

```sh
ssh root@tower 'docker inspect <container> \
  --format "{{index .Config.Labels \"com.docker.compose.project\"}}"'
```

**`<no value>` means there is no project to inherit** — the container is
unraid's, not compose's, and step 5b applies instead. Use `<name>`.

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

## 5b. **[adopt, unraid-managed only]** Remove the old container

A container from unraid's Docker tab has **no compose labels**, so compose
cannot take it over — it builds a second container beside the running one, and
the two fight over the host port and the same `/config`. Remove it first:

```sh
just adopt <container>            # dry run
just adopt <container> --apply
```

That drops the name from unraid's autostart list *and* removes the container.
Nothing is lost — every byte of state is on the appdata bind, and the template
under `/boot/config/plugins/dockerMan/templates-user/` is the rollback: **Add
Container → pick it → Apply** puts it back on the same appdata. It stops being
a rollback the moment the Stack proves out — step 8b disposes of it.

The recipe **refuses a container that already has a compose project** — that
one is adopted in place by `project_name` (step 3), and removing it would
destroy a running service for nothing.

## 6. **[adopt]** Check the appdata still fits

Confirm the uid/gid and the `/config` bind match what is already on disk — a
service that starts with the wrong PUID writes a second config tree and looks
like data loss.

Every Stack takes 99:100 from [common.env](../common.env). Plex and gluetun ran
as 1000:1000 and qbittorrent as 1001:1001, so **their appdata is only compatible
once the chown in [ticket 20](../.scratch/unraid-gitops/issues/20-chown-to-99-100.md)
has run.**

## 6b. **[adopt]** Diff the container's env against the image's

Copy across what the image actually reads, not what the old template set:

```sh
ssh root@tower 'docker inspect <container> --format "{{range .Config.Env}}{{println .}}{{end}}"'
ssh root@tower 'docker image inspect <image>  --format "{{range .Config.Env}}{{println .}}{{end}}"'
```

A variable the image does not declare is either a real setting or **cargo** —
calibre carried eighteen cargo variables [22] and gluetun four [24]. Cargo is not
merely untidy: two of gluetun's were misspelled firewall settings, and copying
them forward invites a later reader to "fix" the spelling, which would route
every packet around the tunnel. Drop them, and say in a comment what the absence
means.

## 7. Deploy

Add the Stack's name to the `BatchDeployStackIfChanged` pattern in
[komodo/procedures.toml](../komodo/procedures.toml) — the list is explicit, and a
Stack missing from it is never deployed. Then commit and push, and run
`just reconcile` for the first deploy.

**Do not just wait 15 minutes for this one.** The cron cannot apply an edit to
`procedures.toml` — only `just reconcile` can, because it syncs before running
the Procedure. Until it runs, every scheduled reconcile fails.

## 7b. Probe it — or say what watches it instead

**A Stack with no HTTP listener has nothing to probe**, and gatus only speaks
HTTP, so it is outside the alerting story by construction. That Stack skips to
7c rather than skipping the question. Everything else continues here.

Add an endpoint to [stacks/gatus/conf/config.yaml](../stacks/gatus/conf/config.yaml).
`scripts/check-probes.sh` fails step 8 without one, because a missing probe is
the one fault with no signature of its own — nothing is down, nothing 404s, the
service simply never appears on the status page [44].

It lands here, after the deploy, because the status has to be **measured**:

```sh
ssh root@tower "curl -s -o /dev/null -w '%{http_code}\n' https://<name>.rbrb.in/"
```

- **Assert that exact status, never `< 400`** [29]. Six of the ten original
  services answer something other than 200 unauthenticated; 302, 303 and 401 are
  all healthy. **404** is Caddy having discarded the block [16], **502** is Caddy
  holding it but unable to reach the container [21] — the two the probe is for.
- **`/`, unless the root moves under a setting in appdata.** Tautulli's root
  changes with its wizard and its password [35] and bazarr's with its UI auth
  [36]; a probe cannot assert a status that appdata governs. Both use a keyless
  health route instead, and where one returns JSON add a `[BODY]` condition —
  that is what makes it better than a bare status.
- **A path answering 200 is not proof it is that route.** Verify the response is
  the backend and not the app shell: bazarr's `/health` and `/ping` fall through
  to its SPA catch-all and answer 200 whatever the backend is doing [36].
- **`ignore-redirect: true`** on every HTTP probe. gatus follows redirects by
  default and would report the login page's 200 instead of the service's own
  302; there is no global form, so it is repeated per endpoint [29].

Commit and push. **The cron applies this one** — step 7's warning is about
`procedures.toml` specifically, not a general rule. `conf/config.yaml` is a
tracked config file with `requires = "restart"`, so the scheduled reconcile
picks it up.

## 7c. Headless: state what watches it

A Stack with no listener declares `x-watch` on the Service — a sentence naming
what notices when it stops, and why that is enough:

```yaml
recyclarr:
  x-watch: >-
    nothing. A sync that stops leaves the *arr holding their last-synced
    settings, which is stale policy rather than a broken service [46].
```

**`nothing, because …` is a legal answer and it has to be earned each time** —
this is argued per Stack, never inherited [46]. Komodo does not cover the gap:
`StackStateChange` fires on container state, and a scheduled job that fails
while its container stays `Up` changes none. Two things the sentence has to
answer:

- **How bad is the silence?** Recyclarr going quiet costs a stale library policy
  and is fixed by running it again. A job whose failure stalls work — unpackerr
  leaving archives unextracted — does not get recyclarr's answer for free.
- **What would surface it anyway?** A downstream probe that would fail, a human
  who would notice within a day, or nothing at all. Say which.

Nothing enforces this yet, which is a gap of exactly the kind [44] describes —
see [53](../.scratch/unraid-gitops/issues/53-lint-the-headless-statement.md).

## 8. Check it

```bash
just lint             # exposure, probes, compose, shell, Dockerfiles
just verify-secrets   # every *.sops.env still decrypts
```

- `https://<name>.rbrb.in` answers from the LAN and the tailnet, and nowhere else.
- **[adopt]** the service's own settings survived — indexers, libraries, history.

## 8b. **[adopt, unraid-managed only]** Delete the template

```sh
ssh root@tower rm /boot/config/plugins/dockerMan/templates-user/my-<name>.xml
```

Step 5b's rollback is now a hazard. The template names the container `<name>`
while the Stack runs `<name>-<name>-1`, so **Add Container → Apply** starts a
*second* container on the same appdata rather than failing on the name — and the
Docker tab and Community Applications' *Previous Apps* both offer it. Deleting
the file is enough; nothing caches it —
[ticket 41](../.scratch/unraid-gitops/issues/41-orphan-unraid-templates.md).

**Read it for secrets before deleting.** `Mask="true"` only hides a value in the
UI; the file itself is cleartext, and `/boot` is the flash drive.

---

## Traps

- **Never bind a single file out of the run directory** — bind its directory. A
  git pull replaces the file, and the bind goes `stale file handle`. It took
  Caddy down on its second deploy while the reconcile reported success.
- **Never bind `/etc/localtime`.** runc under Docker 29.5.3 refuses to mount onto
  it — the path is a symlink inside most images — and the container will not
  start: `not a directory: Are you trying to mount a directory onto a file?`. It
  cost plex an outage after the 7.3.2 upgrade. Old unraid templates offer it;
  `TZ` in `common.env` already does the job.
- **qbittorrent's labels live on gluetun.** It has no network identity of its
  own; the *arr address it as `http://gluetun:30024`.
- **gluetun and qbittorrent deploy together, always.** Recreating gluetun alone
  leaves qbittorrent in a dead namespace with no error.
- **plex** needs `/dev/dri` passthrough, `VERSION: docker`, and appdata at
  `${APPDATA}/plexmediaserver`. Any other `VERSION` makes it download and install
  a Plex build over the image at every start, which unpins the digest [23]. Its
  media binds are `/mnt/<category>`.
- **calibre** binds `${MEDIA}/books` → `/config/Calibre Library`. The space in
  that path is real.
- **homepage** is the one service whose config git owns outright. `/app/config`
  must be **writable** — it seeds missing skeleton files at boot and serves HTTP
  500 if it cannot. The repo ships the complete skeleton so nothing is seeded
  untracked into the clone; logs go to `${APPDATA}/homepage/logs`.
- **recyclarr owns settings inside sonarr and radarr**, and reverts a UI edit to
  any of them on the next sync with no error anywhere.
  [stacks/recyclarr/conf/recyclarr.yml](../stacks/recyclarr/conf/recyclarr.yml)
  is the boundary — it writes only what that file lists. Today: quality
  profiles, custom formats and their scores, and quality definitions. **Media
  naming and media management are deliberately absent** — both apps' naming is
  hand-set to TRaSH's with renaming ON, so a silent revert there would rename
  files on disk [46]. Tune those in the UI; tune anything else in the repo.
- **CoreDNS** binds an explicit host address, `100.126.56.26:53`, not a port on
  every interface. Docker cannot bind that before `tailscale0` is up, so a
  reconcile racing a reboot fails until `restart: unless-stopped` catches up. Its
  `.` block **REFUSEs** — Tailscale Split DNS is restricted to `rbrb.in`, so no
  other name is ever sent there and a forwarder would only mask a
  misconfiguration [17].
- **An image that is not a linuxserver one reads no `PUID`/`PGID`.** Most of this
  repo's images chown `/config` as root and then drop privileges; a plain Go
  binary like ntfy or gatus does neither. Set `user: "${PUID}:${PGID}"` **and**
  pre-create the bind target in `pre_deploy`, because docker creates a missing
  one `root:root` and the container then cannot write to it [29]. `UMASK` is
  inert for these — nothing reads it — which is only acceptable because no human
  shares those trees.
  **The moment one does, inert becomes wrong** [48]. Docker's own umask is
  `022`, and it masks whatever the image is told to write: unpackerr's
  `UN_DIR_MODE: 0775` landed 0755 and its 0664 landed 0644, putting an 8G file
  in a directory rb could not move it out of — [19]'s failure, reintroduced by a
  Stack that looked correct. No mode setting can escape it; the umask itself has
  to change, and for an image with a shell that is
  `entrypoint: ["/bin/sh", "-c", "umask 002; exec /<binary> \"$$@\"", "--"]`.
  **Read the startup log rather than the config** — unpackerr prints its umask
  and never sets it, which is the only reason this was caught.
  **That advice covers appdata and nothing else.** Periphery binds
  `/mnt/user/appdata`, so a `mkdir` under `${MEDIA}` succeeds inside Periphery,
  changes nothing on the host, and leaves docker to make the real target
  `root:root` anyway. A media path is created by hand and the bind declares
  `create_host_path: false`, which turns a missing tree into a failed deploy
  instead of an empty `root:root` one that reads exactly like the correct one
  [47].
- **unpackerr watches a folder; it does not scan one.** Its watcher baselines
  whatever is already in `${MEDIA}/downloads` at startup, so a release that was
  sitting there before the Stack existed is never extracted. `touch` the release
  directory to fire an event. Its webserver also needs **both**
  `UN_WEBSERVER_METRICS` and `UN_WEBSERVER_LISTEN_ADDR` — `Enabled()` is the two
  ANDed, so the address alone logs `Webserver Disabled` while the container sits
  `Up` [48].
- **gatus is host-networked**, so caddy-docker-proxy never sees its labels — it
  reads only containers on `shared`. `status.rbrb.in` lives in the Caddyfile
  instead, alongside `komodo` and `unraid` [29]. Adding a probe means editing
  `stacks/gatus/conf/config.yaml`, and the condition is the service's **actual**
  unauthenticated status: 302, 303 and 401 are all healthy answers here.
- **ntfy has two doors and they are not interchangeable** [29]. `:8095` on the
  tailnet is the alert path — publishers and the phone — because an alert routed
  through Caddy cannot report a Caddy outage. `ntfy.rbrb.in` is for a browser
  only, whose notifications need a secure context. Pointing the phone at the
  hostname silently undoes the design.
