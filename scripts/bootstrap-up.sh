#!/usr/bin/env bash
# Apply bootstrap/ to the box. Tickets 11, 29.
#
# The four Komodo containers are the one thing here that is not GitOps'd, and
# cannot be: Periphery cannot redeploy itself, since that kills the process
# running the deploy. So a change to bootstrap/ reaches the box only by hand --
# and this recipe is that hand, so it stops being a paste-back checklist that
# goes stale. Both places that carried those steps as prose had them wrong: they
# said `git pull` in a directory that is a copy rather than a clone, and
# `docker compose` on a host that has none.
#
# There is no compose on the Unraid host, by design [01]. The way out is that
# the Periphery *image* is a compose implementation, so a throwaway container
# deploys the stack it belongs to. Throwaway matters: recreating Periphery from
# inside the running Periphery would kill the deploy half-way.

# SC2029: the paths below are constants defined here and are the same on both
# sides, so expanding them client-side is the intent, not an accident.
# shellcheck disable=SC2029

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tower="${TOWER_SSH:-root@tower}"
remote="/mnt/user/appdata/komodo/bootstrap"

# Everything except the decrypted secrets.env, which is written by hand on the
# box and is deliberately not in git [03].
files=(compose.yaml compose.env secrets.sops.env README.md)

# Read the tag off compose.yaml rather than pinning it here, or the two drift
# and the compose that deploys the bump is the one being replaced.
periphery_image() {
    yq -r '.services.periphery.image' "$root/bootstrap/compose.yaml"
}

# Identical paths inside and outside, or compose path resolution breaks --
# komodo#180, and the same reason PERIPHERY_ROOT_DIRECTORY is what it is.
compose() {
    ssh "$tower" "docker run --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v /mnt/user/appdata/komodo:/mnt/user/appdata/komodo \
        -w $remote \
        --entrypoint docker $(periphery_image) \
        compose -p komodo --env-file compose.env --env-file secrets.env $*"
}

changed=0
echo "  bootstrap/ -> ${tower}:${remote}"
for f in "${files[@]}"; do
    if ssh "$tower" "cat $remote/$f" 2>/dev/null | diff -q - "$root/bootstrap/$f" >/dev/null 2>&1; then
        printf '    %-18s same\n' "$f"
    else
        printf '    %-18s DIFFERS\n' "$f"
        ssh "$tower" "cat $remote/$f" 2>/dev/null |
            diff -u - "$root/bootstrap/$f" 2>/dev/null |
            sed -n '3,$p' | sed 's/^/      /' | head -40 || true
        changed=1
    fi
done

echo
echo "  then, in a throwaway $(periphery_image):"
echo "    docker compose -p komodo up -d"

if ((!changed)); then
    echo
    echo "nothing differs -- the box already has this bootstrap"
fi

case "${1:-}" in
--apply) ;;
*)
    echo
    echo "dry run -- nothing was changed. re-run with:  just bootstrap-up --apply"
    echo "note this recreates Komodo Core and Periphery. Nothing deploys while"
    echo "they are down, and the rollback is to restore the previous bootstrap/"
    echo "from git and run this again -- appdata and the database are untouched."
    exit 0
    ;;
esac

for f in "${files[@]}"; do
    scp -q "$root/bootstrap/$f" "$tower:$remote/$f"
done
echo "  copied"

compose up -d
echo
compose ps
