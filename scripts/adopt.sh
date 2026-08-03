#!/usr/bin/env bash
# Hand a container from unraid's Docker tab to compose. Ticket 21.
#
# Since ticket 22 the only container unraid's Docker tab still owns is
# PortainerCE, which ticket 25 retires rather than adopts -- and a rebuilt box
# is a fresh unraid install Komodo populates from git, so no adoption is on the
# route. It takes any container name rather than a Stack, though, so it still
# works the day something is installed from Community Applications and wants to
# come in.
#
# An unraid dockerMan container carries no com.docker.compose.* labels, so
# there is nothing for compose to take over: `docker compose up` in the Stack
# builds a *second* container beside the running one and the two fight over the
# host port and the same /config. Adoption is therefore removal -- every byte
# of state is on the appdata bind, so the container itself is disposable.
#
# A Portainer container is the opposite case and is refused here: it already
# carries a compose project, so `project_name` in komodo.toml adopts it in
# place and removing it would be destroying a running service for nothing.
#
# The template under /boot/config/plugins/dockerMan/templates-user/ is left
# alone on purpose -- it is the rollback.

set -euo pipefail

tower="${TOWER_SSH:-root@tower}"

usage() {
    echo "usage: adopt.sh <container> [--apply]" >&2
    exit 1
}

name="${1:-}"
[[ -n "$name" ]] || usage

apply=0
case "${2:-}" in
--apply) apply=1 ;;
"") ;;
*) usage ;;
esac

# This name reaches the box inside a remote command. Bare only.
if [[ ! "$name" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]*$ ]]; then
    echo "refusing: '$name' is not a bare container name" >&2
    exit 1
fi

# Passed on argv over stdin rather than interpolated into the command line, so
# nothing here is ever re-parsed by the remote shell.
survey="$(ssh "$tower" bash -s -- "$name" <<'REMOTE'
set -eu
name=$1
label() { docker inspect -f "{{index .Config.Labels \"$2\"}}" "$1" 2>/dev/null | sed 's/^<no value>$//'; }

if docker inspect "$name" >/dev/null 2>&1; then
    echo "exists=yes"
    echo "status=$(docker inspect -f '{{.State.Status}}' "$name")"
    echo "image=$(docker inspect -f '{{.Config.Image}}' "$name")"
    echo "managed=$(label "$name" net.unraid.docker.managed)"
    echo "project=$(label "$name" com.docker.compose.project)"
else
    echo "exists=no"
fi

if grep -qxF "$name" /var/lib/docker/unraid-autostart 2>/dev/null; then
    echo "autostart=yes"
else
    echo "autostart=no"
fi
REMOTE
)"

field() { sed -n "s/^$1=//p" <<<"$survey"; }

exists="$(field exists)"
autostart="$(field autostart)"

if [[ "$exists" == no ]]; then
    if [[ "$autostart" == no ]]; then
        echo "$name is already gone from $tower -- nothing to do."
        exit 0
    fi
    echo "$name no longer exists on $tower, but unraid still autostarts the name."
else
    managed="$(field managed)"
    project="$(field project)"

    if [[ -n "$project" ]]; then
        echo "$name belongs to compose project '$project' -- refusing." >&2
        echo "set project_name = \"$project\" in its komodo.toml instead; Komodo" >&2
        echo "adopts it in place and this script would only destroy it." >&2
        exit 1
    fi
    if [[ "$managed" != dockerman ]]; then
        echo "$name is not managed by unraid's Docker tab -- refusing." >&2
        echo "this script only removes containers it can name a rollback for." >&2
        exit 1
    fi

    echo "  container  $name ($(field status), $(field image))"
fi

echo "  autostart  $autostart"
echo
echo "would, on $tower:"
[[ "$autostart" == yes ]] && echo "  drop '$name' from /var/lib/docker/unraid-autostart"
[[ "$exists" == yes ]] && echo "  docker stop $name && docker rm $name"
echo
echo "appdata is untouched -- the Stack rebinds the same /config."

if ((!apply)); then
    echo
    echo "dry run -- nothing was changed. re-run with:  just adopt $name --apply"
    exit 0
fi

ssh "$tower" bash -s -- "$name" <<'REMOTE'
set -eu
name=$1
list=/var/lib/docker/unraid-autostart

if [ -f "$list" ] && grep -qxF "$name" "$list"; then
    grep -vxF "$name" "$list" >"$list.tmp"
    mv "$list.tmp" "$list"
    echo "dropped $name from unraid-autostart"
fi

if docker inspect "$name" >/dev/null 2>&1; then
    docker stop "$name" >/dev/null
    docker rm "$name" >/dev/null
    echo "removed container $name"
fi
REMOTE

echo
echo "$name is free. deploy its Stack with: just reconcile"
echo "to undo: re-add it from its template in unraid's Docker tab -- Add"
echo "Container, pick $name, Apply. Its appdata never moved."
