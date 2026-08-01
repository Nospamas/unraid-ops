# 03 — Decide how secrets live in the repo

Type: grilling
Status: closed
Assignee: Nospamas
Resolved: 2026-08-01
Blocked by: 02

## Question

The repo needs API keys for the *arr services and qbittorrent (homepage widgets
consume them), plus VPN credentials for the torrent container. Where do they
live, and how do they reach a running container?

**The full set, per [01](01-inventory-running-containers.md)**: the NordVPN
`WIREGUARD_PRIVATE_KEY`, `PLEX_CLAIM`, calibre's `PASSWORD` + `CUSTOM_USER`, and
the sonarr/radarr/prowlarr/qbittorrent API keys. Note the last group are **not**
environment variables — they live in each service's `/config/config.xml` inside
appdata, so nothing needs to inject them *into* the *arr containers. Homepage is
their only consumer.

**Do not raise rotation as a blocker.** The human has ruled the leaked WireGuard
key and calibre password low-severity; see the map's Secret severity note.
Picking a mechanism here will re-issue the WireGuard key as a side effect, which
settles it without a separate act.

**[02](02-choose-reconcile-mechanism.md) has resolved, and it changes the menu.**
The mechanism is Komodo, which brings three *native* routes that were not on the
original list:

- **Komodo Variables** — key/value in Komodo's database, marked secret,
  interpolated as `[[KEY]]` into a Stack's `environment`, which Komodo writes to
  a `.env` and passes as `--env-file`.
- **`core.config.toml` secrets** — on the box, never exposed by the API to any
  user.
- **`periphery.config.toml` secrets** — on the box, scoped to that one server,
  never sent over the network.

All three are variants of "off-git `.env` on the box": the value lives in
Komodo's database or in TOML on disk, and the repo cannot rebuild it. They are
*better* versions of that option, not a different one.

**SOPS survives, at a price.** Komodo Stacks have a `pre_deploy` SystemCommand,
which is a real pre-apply hook and the reason Komodo was chosen over Portainer
here. But the Periphery image has no `sops` binary, so SOPS means building a
custom Periphery image or running a decrypt sidecar. Weigh that against the
rebuild story it buys.

Note also that **`--env-file` writes plaintext to disk** on the way to the
container, which bears directly on the last question below.

Options in play:

- **SOPS + age**, matching the home-ops habit — encrypted values committed here,
  the age key held on the unraid box. Cost: the reconcile mechanism must
  decrypt before applying, which ticket 02 will have established is possible or
  not.
- **Off-git `.env` on the box** — compose files reference `${SONARR_KEY}`, the
  real values never leave the host. Simplest, but the box holds state the repo
  cannot rebuild.
- **An external secrets manager** — Infisical, 1Password Connect. Most
  machinery, best rebuild story.

Resolve alongside it: where the age key (or equivalent root secret) is kept so a
box rebuild is possible, and whether a secret ever appears in plaintext on disk
between decryption and container start.

The answer states the mechanism and the rebuild story in a few lines.

## Resolution

**SOPS + age**, encrypted files committed to this repo — matching the home-ops
habit and its [ADR 0001](https://github.com/Nospamas/home-ops) reasoning: a
single source of truth in git, no external secret store to run or trust, with
the age private key as the one out-of-band credential.

**How it reaches a container.** A Komodo Stack `pre_deploy` SystemCommand runs
`sops -d secrets.sops.env > secrets.env`, and the Stack declares
`additional_env_files: [secrets.env]`. The distinct filename matters: Komodo
already generates its *own* `.env` from a Stack's `environment` field, so
decrypting to `.env` would clobber it.

**[02](02-choose-reconcile-mechanism.md) over-priced this.** It flagged that the
Periphery image has no `sops` binary and concluded that meant a custom image or
a decrypt sidecar. Neither is needed: sops is a single static Go binary and
Periphery is Debian-based, so it is **bind-mounted in** from
`/mnt/user/appdata/komodo/bin/sops` → `/usr/local/bin/sops:ro`, one volume line
on Periphery's own compose. Version and sha256 get recorded in this repo so a
rebuild is one documented `curl`.

A custom image was rejected on a chicken-and-egg problem, not just on effort:
Periphery is the container that *runs* deployments, so rebuilding it through
Komodo means the deployment system rebuilding itself, and every upstream
Periphery release becomes a manual rebuild that must not be forgotten. The
bind-mount is untouched by Periphery upgrades.

Rejected: **Komodo Variables**, **`core.config.toml`** and
**`periphery.config.toml`** — all three put the *values* in Komodo's database or
in a hand-maintained file on the box, which reintroduces at the secrets layer
the exact flaw that killed Portainer in 02: state the repo cannot rebuild.
**External managers** (Infisical, 1Password Connect) — most machinery, and
another always-on dependency between a push and a container starting, for five
values that change roughly never.

### The root secret and the rebuild story

**A fresh age keypair for this repo**, not the home-ops one. This honours the
map's "relationship: none" note — a rotation or compromise on either side never
touches the other, and the unraid box never holds a key that decrypts the k8s
cluster, which matters given [05](05-remote-access.md) will put this box on the
internet.

- **On the box**: `/mnt/user/appdata/komodo/age.key`, mode 600, bind-mounted
  read-only into Periphery beside the sops binary.
- **Explicitly not on `/boot`.** Unraid Connect backs the flash drive up
  off-site, and [01](01-inventory-running-containers.md) already found the
  calibre password sitting there in plaintext. The root secret must not be
  shipped to Unraid's servers.
- **Off-site**: **KeePassXC**, synced across devices by Syncthing — so the
  off-site copy is genuinely multi-device and self-refreshing rather than one
  copy that has to be remembered.
- **Laptop**: for `sops -e` when editing a secret. Three copies, two failure
  domains.

**Rebuild**: clone the repo, restore one age key from KeePassXC, stand Periphery
up with `age.key` and the sops binary mounted. Everything else regenerates.

### Plaintext on disk: yes, and deliberately left

`secrets.env` persists in the stack directory under `/mnt/user/appdata/komodo`.
The boundary defended is **directory permissions on the komodo appdata tree**,
not the file. Scrubbing it in a `post_deploy` hook would be theatre — the age
key that regenerates it sits in the same tree, and `docker inspect` exposes
every container's environment to anyone on the box regardless. A tmpfs was
rejected because 02 established `PERIPHERY_ROOT_DIRECTORY` must resolve to an
identical path inside and outside the container while the stacks tree must
persist for git clones, so it means a fiddly hand-managed sub-mount for no real
gain on a box where `docker inspect` is already open.

### Facts later tickets lean on

- **`PLEX_CLAIM` is not a secret and leaves the set.** It is a one-shot token
  that expires minutes after issue and is only read on first claim; plex is
  already claimed and running per 01. It belongs in the compose file as an
  absent var. **Five live values remain**, not six: the NordVPN
  `WIREGUARD_PRIVATE_KEY`, calibre's `PASSWORD` + `CUSTOM_USER`, and the
  sonarr/radarr/prowlarr/qbittorrent API keys.
- **No secret needs injecting into an *arr container.** All five live values are
  env vars into exactly one container each, and the *arr API keys' only consumer
  is homepage — they live in each service's own `/config/config.xml` already.
  home-ops proves the pattern lifts to Docker unchanged: `key:
  '{{HOMEPAGE_VAR_SONARR_TOKEN}}'` in `services.yaml` reading an env var.
- **The *arr API keys do not exist anywhere in this repo yet** and must be read
  out of each service's `/config/config.xml` on the box — a HITL fetch, since
  there is no agent access. Handed to [08](08-deploy-homepage.md), homepage
  being the only consumer.
- **File naming and directory convention** for `*.sops.env` and `.sops.yaml`
  is [07](07-repo-layout-and-conventions.md)'s to settle, not this ticket's.
  Note the format is **dotenv**, not YAML, since the consumer is `--env-file`.
- **Local tooling is now specifiable** — mise must pin `sops` and `age`, and the
  task runner needs secret-editing commands. Graduated out of the fog as
  [13](13-local-tooling.md).

### A correction to the map

The map's Secret severity note claimed "03 will re-issue the WireGuard key as a
side effect of picking a mechanism anyway." **That is not true and has been
corrected on the map.** SOPS encrypts the existing value perfectly well, so
nothing about this decision forces a new key. Re-issuing is a separate manual
NordVPN dashboard visit.

This does not reopen severity — the human ruled both leaked assets low-value and
that ruling stands. It is recorded only so no future session inherits a false
belief that rotation happened for free. The cheap opportunity, if ever wanted:
generating a fresh key costs almost nothing at the moment the value is first
pasted into SOPS, because it is being handled anyway.
