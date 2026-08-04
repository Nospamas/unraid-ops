#!/usr/bin/env bash
# Put Komodo on the box, and this repo into Komodo. Tickets 11, 29.
#
# One command for both halves, because they were never separable: declaring the
# ResourceSync needs a Core to declare it to, and standing Core up without
# declaring the sync leaves a running Komodo that has never heard of this repo.
#
# Idempotent by construction -- every phase reports what is already true and
# does only what is missing, so this is the same command on a fresh box and on
# a running one. That is what makes it the answer to "apply a Komodo bump" as
# well as to "rebuild the box".
#
# The four Komodo containers are the one thing here that cannot be GitOps'd:
# Periphery cannot redeploy itself, since that kills the process running the
# deploy. And there is no compose on the Unraid host, by design [01] -- the way
# out is that the Periphery *image* is a compose implementation, so a throwaway
# container deploys the stack it belongs to. Throwaway is the point: running it
# inside the live Periphery would kill the deploy half-way.
#
# SC2029: the remote paths below are constants defined here and identical on
# both sides, so expanding them client-side is the intent.
# shellcheck disable=SC2029

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tower="${TOWER_SSH:-root@tower}"

komodo="/mnt/user/appdata/komodo"
remote="$komodo/bootstrap"
# Postgres and FerretDB state sit on the cache disk, reached without shfs.
ferretdb="/mnt/cache/appdata/komodo/ferretdb"

# Not secrets.env: it is derived below, and never leaves the box.
files=(compose.yaml compose.env secrets.sops.env README.md)

apply=0
case "${1:-}" in
--apply) apply=1 ;;
"") ;;
*)
    echo "usage: bootstrap.sh [--apply]" >&2
    exit 1
    ;;
esac

todo=()
plan() {
    printf '  * %s\n' "$1"
    todo+=("$1")
}
have() { printf '    %s\n' "$1"; }

on() { ssh "$tower" "$1"; }

# Read the tag out of compose.yaml rather than pinning it here, or the compose
# that applies a Komodo bump is the one being replaced.
periphery_image="$(yq -r '.services.periphery.image' "$root/bootstrap/compose.yaml")"
sops_version="$(yq -r '.tools["aqua:getsops/sops"]' "$root/.mise.toml")"

echo "bootstrap -> $tower"
echo

# --- 1. the age key -----------------------------------------------------------
# The root of the whole secret story [03]. A rebuild restores it from KeePassXC;
# a clone that can already decrypt has it, and copying is less error-prone than
# retyping.
if on "test -f $komodo/age.key"; then
    have "age.key present"
elif [[ -f "$root/age.key" ]]; then
    plan "copy age.key from this clone (mode 600)"
else
    echo "  ! no age.key here and none on the box -- restore it from KeePassXC to" >&2
    echo "    $root/age.key before running this" >&2
    exit 1
fi

# --- 2. the sops binary -------------------------------------------------------
# One static binary, bind-mounted into Periphery rather than baked into a custom
# image -- which would mean rebuilding the container that runs every deploy [03].
if [[ "$(on "$komodo/bin/sops --version 2>/dev/null | head -1" || true)" == *"$sops_version"* ]]; then
    have "sops $sops_version present"
else
    plan "fetch sops $sops_version, verified against the release checksums"
fi

# --- 3. FerretDB's state directory --------------------------------------------
# Docker creates a missing bind target root:root and FerretDB runs as uid 1000,
# so without this it crashloops on `open /state/state.json: permission denied`.
# 1000:1000 is deliberately not the repo's 99:100 -- that rule governs Stacks,
# and the uid is baked into the image [09].
if [[ "$(on "stat -c %u:%g $ferretdb 2>/dev/null" || true)" == "1000:1000" ]]; then
    have "ferretdb state directory owned by 1000:1000"
else
    plan "create $ferretdb/state and chown it 1000:1000"
fi

# --- 4. the bootstrap directory -----------------------------------------------
changed=()
for f in "${files[@]}"; do
    if on "cat $remote/$f" 2>/dev/null | diff -q - "$root/bootstrap/$f" >/dev/null 2>&1; then
        have "bootstrap/$f up to date"
    else
        changed+=("$f")
    fi
done
((${#changed[@]})) && plan "copy ${changed[*]}"

# Only a compose change recreates anything; the README moving does not.
recreates=0
for f in "${changed[@]}"; do
    [[ "$f" == compose.* ]] && recreates=1
done

# --- 5. secrets.env -----------------------------------------------------------
# The one sops invocation that is not a pre_deploy, because there is no Komodo
# yet to run one. umask 077 rather than a chmod afterwards: it closes the window
# instead of reopening it [19].
#
# Compared by hash so the check never puts plaintext on a terminal or a pipe.
secrets_local="$(sops --decrypt "$root/bootstrap/secrets.sops.env" | sha256sum | cut -d' ' -f1)"
if [[ "$(on "sha256sum $remote/secrets.env 2>/dev/null | cut -d' ' -f1" || true)" == "$secrets_local" ]]; then
    have "secrets.env current"
else
    plan "decrypt secrets.env on the box, umask 077"
    recreates=1
fi

# --- 6. the containers --------------------------------------------------------
if ((recreates)); then
    plan "docker compose up -d -- recreates Core and Periphery"
else
    have "containers already match this compose; up -d will be a no-op"
fi

# --- 7. the ResourceSync ------------------------------------------------------
# Everything Komodo runs comes from git, but the sync that reads git cannot
# itself come from git -- so this one resource is created from komodo/sync.toml
# and then declares itself. Idempotent, and reports which case it found.
plan "declare the ResourceSync, if Komodo does not have it"

if ((!apply)); then
    echo
    if ((!${#todo[@]})); then
        echo "nothing to do -- the box already has all of this"
    fi
    echo "dry run -- nothing was changed. re-run with:  just bootstrap --apply"
    if ((recreates)); then
        echo
        echo "note this recreates Komodo Core and Periphery. Nothing deploys while"
        echo "they are down; appdata and the database are untouched, and the rollback"
        echo "is to restore the previous bootstrap/ from git and run this again."
    fi
    exit 0
fi

echo
echo "applying"

if ! on "test -f $komodo/age.key"; then
    scp -q "$root/age.key" "$tower:$komodo/age.key"
    on "chmod 600 $komodo/age.key"
    echo "  age.key copied"
fi

if [[ "$(on "$komodo/bin/sops --version 2>/dev/null | head -1" || true)" != *"$sops_version"* ]]; then
    on "set -e
        mkdir -p $komodo/bin
        cd \$(mktemp -d)
        curl -fsSLO https://github.com/getsops/sops/releases/download/v$sops_version/sops-v$sops_version.linux.amd64
        curl -fsSLO https://github.com/getsops/sops/releases/download/v$sops_version/sops-v$sops_version.checksums.txt
        grep ' sops-v$sops_version.linux.amd64\$' sops-v$sops_version.checksums.txt | sha256sum -c -
        install -m 755 sops-v$sops_version.linux.amd64 $komodo/bin/sops"
    echo "  sops $sops_version installed"
fi

on "mkdir -p $ferretdb/state && chown -R 1000:1000 $ferretdb"
on "mkdir -p $remote"
for f in "${files[@]}"; do
    scp -q "$root/bootstrap/$f" "$tower:$remote/$f"
done
echo "  bootstrap/ copied"

if [[ "$(on "sha256sum $remote/secrets.env 2>/dev/null | cut -d' ' -f1" || true)" != "$secrets_local" ]]; then
    on "cd $remote && (umask 077; SOPS_AGE_KEY_FILE=$komodo/age.key $komodo/bin/sops --decrypt secrets.sops.env > secrets.env)"
    echo "  secrets.env decrypted"
fi

on "docker run --rm \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v $komodo:$komodo \
    -w $remote \
    --entrypoint docker $periphery_image \
    compose -p komodo --env-file compose.env --env-file secrets.env up -d"

# Core takes a moment to answer after a recreate, and the sync below needs it.
printf '  waiting for Core'
for _ in $(seq 30); do
    on "curl -sf -o /dev/null --max-time 3 http://localhost:9120/" 2>/dev/null && break
    printf '.'
    sleep 2
done
echo

bash "$root/scripts/komodo.sh" bootstrap --apply
