# Komodo bootstrap: box checklist

Hand-off for [11 — Stand Komodo up on the box](../issues/11-stand-up-komodo.md).
Everything runs in the Unraid Web UI terminal. Paste the output of each block
back; the ticket's answer is written from it.

Run the blocks **in order** — block 1 can veto blocks 2 onward.

---

## Block 1 — Pre-flight (read-only, changes nothing)

```sh
echo "== AVX (mongo 8 needs it) =="
grep -o -m1 -w avx /proc/cpuinfo || echo "NO AVX"

echo "== is 9120 free? =="
(ss -ltnp 2>/dev/null || netstat -ltnp) | grep -E ':(9120|80|443)\b' || echo "9120/80/443 all free"

echo "== does the host have compose after all? =="
docker compose version 2>&1 | head -1

echo "== compose project names (07 needs these exactly) =="
docker compose ls --all 2>&1

echo "== outbound HTTPS to github =="
curl -sI https://github.com/Nospamas/unraid-ops | head -1

echo "== can the box clone the repo with no credential? =="
git clone --depth 1 https://github.com/Nospamas/unraid-ops /tmp/rt 2>&1 | tail -2 \
  && ls /tmp/rt && rm -rf /tmp/rt

echo "== the age key 13 placed =="
ls -l /mnt/user/appdata/komodo/age.key
```

**Stop and report if:**

- `NO AVX` — MongoDB 8 will not start. Swap `bootstrap/compose.yaml`'s `mongo`
  service for FerretDB-on-Postgres; Komodo supports it for exactly this reason.
- `git clone` prompts for credentials — the repo is not public, which resurrects
  the bootstrap-secret question [10](../issues/10-publish-repo-to-remote.md)
  dissolved.
- `docker compose version` prints a version — the host does have compose, and
  the whole container-alias dance below is unnecessary (use it directly). This
  contradicts [01](../issues/01-inventory-running-containers.md); worth knowing
  either way.

---

## Block 2 — Place the files

The repo is public, so clone it straight onto the box rather than copying
`bootstrap/` across:

```sh
mkdir -p /mnt/user/appdata/komodo/bin
cd /mnt/user/appdata/komodo
git clone --depth 1 https://github.com/Nospamas/unraid-ops /tmp/ops
cp -r /tmp/ops/bootstrap /mnt/user/appdata/komodo/bootstrap
rm -rf /tmp/ops

curl -fsSL -o /mnt/user/appdata/komodo/bin/sops \
  https://github.com/getsops/sops/releases/download/v3.13.3/sops-v3.13.3.linux.amd64
echo "e5bec3346a873ae91d871550f3e698c1aad962aff462a080e40f25fde17fef6b  /mnt/user/appdata/komodo/bin/sops" | sha256sum -c -
chmod 755 /mnt/user/appdata/komodo/bin/sops

chmod 600 /mnt/user/appdata/komodo/age.key
ls -ld /mnt/user/appdata/komodo /mnt/user/appdata/komodo/age.key /mnt/user/appdata/komodo/bin/sops
```

The `chmod 600` matters: [19](../issues/19-secret-hygiene-on-the-box.md) found
appdata sitting at 777, and [03](../issues/03-secrets-handling.md) leans on
directory perms as the boundary for decrypted plaintext.

## Block 3 — Decrypt, by hand, once

```sh
cd /mnt/user/appdata/komodo/bootstrap
SOPS_AGE_KEY_FILE=/mnt/user/appdata/komodo/age.key \
  /mnt/user/appdata/komodo/bin/sops --decrypt secrets.sops.env > secrets.env
chmod 600 secrets.env
grep -c '^KOMODO' secrets.env
```

Expect `6`. **This is the first proof the box's copy of the age key works** —
[13](../issues/13-local-tooling.md) placed it but nothing had decrypted with it.
If this fails, the key on the box is not the key in `.sops.yaml`.

## Block 4 — Up

```sh
cd /mnt/user/appdata/komodo/bootstrap
alias dc='docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /mnt/user/appdata/komodo:/mnt/user/appdata/komodo \
  -w /mnt/user/appdata/komodo/bootstrap \
  --entrypoint docker ghcr.io/moghtech/komodo-periphery:2.3.1 compose -p komodo'

dc version
dc --env-file compose.env --env-file secrets.env up -d
docker ps --format '{{.Names}}\t{{.Status}}\t{{.Ports}}' | grep komodo
```

If `dc version` fails, the Periphery image does not carry the compose plugin
where expected — fall back to Portainer's web editor per
[bootstrap/README.md](../../../bootstrap/README.md), and **report it**, because
it also breaks the rebuild story that file describes.

Then open `http://192.168.1.195:9120` and log in with the credentials in
`secrets.env`.

## Block 5 — Verify what the ticket asked

```sh
echo "== komodo version =="
docker exec komodo-core /usr/local/bin/komodo-core --version 2>/dev/null \
  || docker inspect komodo-core --format '{{index .Config.Labels "org.opencontainers.image.version"}}'

echo "== does periphery see the host's containers? =="
docker exec komodo-periphery docker ps --format '{{.Names}}'

echo "== can periphery create a network from a pre_deploy? (07) =="
docker exec komodo-periphery sh -c \
  'docker network inspect shared >/dev/null 2>&1 || docker network create shared' \
  && docker network ls | grep shared

echo "== does sops work inside periphery, with the mounted key? (03) =="
docker exec komodo-periphery sops --decrypt \
  /mnt/user/appdata/komodo/bootstrap/secrets.sops.env | grep -c '^KOMODO'

echo "== does a relative env file escape the run directory? (07) =="
mkdir -p /tmp/envtest/stacks/probe
printf 'PROBE=yes\n' > /tmp/envtest/common.env
printf 'services:\n  p:\n    image: busybox\n    command: env\n' \
  > /tmp/envtest/stacks/probe/compose.yaml
docker run --rm -v /tmp/envtest:/tmp/envtest -w /tmp/envtest/stacks/probe \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --entrypoint docker ghcr.io/moghtech/komodo-periphery:2.3.1 \
  compose --env-file ../../common.env -f compose.yaml config 2>&1 | head -5
rm -rf /tmp/envtest
```

The last one is the cheap version of 07's unverified `additional_env_files =
["../../common.env"]`. It only proves compose accepts the relative path; the
real proof is the first Stack Komodo deploys, in
[08](../issues/08-deploy-homepage.md).

## Block 6 — In the Komodo UI

- **Confirm the Server `tower` is connected** (Servers page, green). Periphery
  dials Core in v2, so there is no passkey to paste — the two auto-generate a
  keypair into `/mnt/user/appdata/komodo/keys`.
- **Confirm it lists all nine containers** — the eight workloads plus
  `PortainerCE`, alongside Komodo's own three.
- **Adopt the two Portainer stacks read-only.** Create two Stacks with
  `files_on_host` pointing at `/mnt/user/appdata/portainer/compose/<...>` and
  `project_name` set to the exact names from block 1's `docker compose ls`.
  **Do not deploy them.** Confirm Komodo shows them matched and healthy — that
  is the proof adoption-by-project-name works.
- **Leave `git_account` empty** on any Stack that clones the repo, and confirm
  the clone succeeds. The struct's own doc comment says an empty string clones
  public repos; this makes it real.
- **Do not remove Portainer.** [02](../issues/02-choose-reconcile-mechanism.md)
  retires it only once every workload reconciles from the repo.

---

## What to paste back

All six blocks' output, plus from the UI: the Komodo version in the footer,
whether `tower` connected, the container count Periphery reports, and whether
the two adopted Stacks matched.
