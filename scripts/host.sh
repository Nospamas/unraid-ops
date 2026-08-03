#!/usr/bin/env bash
# Host settings that live outside Komodo's reach. Ticket 15.
#
# Unraid keeps its identity settings in /boot/config/ident.cfg on the flash.
# Komodo cannot touch them, so they are the one part of the box a `git push`
# does not reconcile -- bootstrap/host/ident.cfg is a snapshot for the rebuild
# story, and `check` is what keeps it honest.
#
# `ports` applies only the Management Access page. It drives emhttpd through
# the same unix socket the GUI's Apply button posts to, so ident.cfg and
# emhttpd's var.ini move together and nginx reloads itself -- copying the file
# into place would update neither.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
snapshot="$root/bootstrap/host/ident.cfg"
live="/boot/config/ident.cfg"
tower="${TOWER_SSH:-root@tower}"

# The Management Access page submits its whole form. emhttpd's handler is a
# binary, so whether an omitted field keeps its value is unknowable -- send all
# seven. A dropped USE_SSH=yes costs the box's only lifeline.
fields=(USE_SSL PORT PORTSSL USE_TELNET PORTTELNET USE_SSH PORTSSH)
pattern="^($(IFS='|'; echo "${fields[*]}"))="

# Unraid writes ident.cfg CRLF -- rc.nginx runs it through `fromdos` for the
# same reason. The snapshot keeps the CRLF so `check` can diff it byte-for-byte.
value() {
    tr -d '\r' <"$snapshot" | sed -n "s/^$1=\"\(.*\)\"$/\1/p"
}

show_live() {
    # shellcheck disable=SC2029  # $pattern is built here on purpose
    ssh "$tower" "grep -E '$pattern' $live" | sed 's/^/  /'
}

check() {
    local out
    # shellcheck disable=SC2029  # $live is this script's constant, not the box's
    if out="$(ssh "$tower" "cat $live" | diff -u "$snapshot" -)"; then
        echo "ok  $tower matches bootstrap/host/ident.cfg"
    else
        echo "$out"
        echo
        echo "the box has drifted from the snapshot (- snapshot, + box)"
        echo "a setting changed in the GUI is the box's, not a fault; re-snapshot:"
        echo "  ssh $tower 'cat $live' > bootstrap/host/ident.cfg"
        return 1
    fi
}

# Reads the box's current Management Access fields into `live_vals`.
read_live() {
    local k v
    live_vals=()
    # shellcheck disable=SC2029  # $pattern is built here on purpose
    while IFS='=' read -r k v; do
        v="${v%$'\r'}" # ident.cfg is CRLF
        v="${v#\"}"
        v="${v%\"}"
        live_vals["$k"]="$v"
    done < <(ssh "$tower" "grep -E '$pattern' $live")
}

ports() {
    local apply=0 f v query="" changed=0
    case "${1:-}" in
    --apply) apply=1 ;;
    "") ;;
    *)
        echo "usage: host.sh ports [--apply]" >&2
        exit 1
        ;;
    esac

    for f in "${fields[@]}"; do
        v="$(value "$f")"
        # Bare alphanumerics only -- these become a query string inside a
        # single-quoted remote command, so anything else is an injection.
        if [[ ! "$v" =~ ^[A-Za-z0-9]+$ ]]; then
            echo "$f is missing or not a bare value in $snapshot -- refusing" >&2
            exit 1
        fi
        query+="&$f=$v"
    done
    # SSH is both the path this runs over and the path that undoes it.
    if [[ "$(value USE_SSH)" != yes ]]; then
        echo "snapshot has USE_SSH != yes -- that closes the lifeline" >&2
        exit 1
    fi

    read_live
    for f in "${fields[@]}"; do
        v="$(value "$f")"
        if [[ "${live_vals[$f]:-}" == "$v" ]]; then
            echo "  $f=$v"
        else
            echo "* $f=${live_vals[$f]:-<unset>} -> $v"
            changed=1
        fi
    done

    if ((!changed)); then
        echo
        echo "the box already matches the snapshot -- nothing to do."
        return
    fi

    echo
    echo "would run on $tower:"
    echo "  emcmd 'changePorts=Apply${query}'"

    if ((!apply)); then
        echo
        echo "dry run -- nothing was changed. re-run with:  just host-ports --apply"
        echo "note this moves the port the Unraid GUI answers on. after applying,"
        echo "reconnect at http://192.168.1.195:$(value PORT)."
        return
    fi

    # shellcheck disable=SC2029  # $query is built here, and validated above
    ssh "$tower" "emcmd 'changePorts=Apply${query}'"
    sleep 2
    echo "on the box after:"
    show_live

    echo
    echo "reconnect at http://192.168.1.195:$(value PORT) -- the old port is gone."
    echo "to undo: put the old values in the snapshot and re-run, or on the box"
    echo "restore ident.cfg and run /etc/rc.d/rc.nginx reload, which regenerates"
    echo "nginx's config straight from the file and needs no emhttpd."
}

declare -A live_vals

case "${1:-}" in
check) check ;;
ports)
    shift
    ports "$@"
    ;;
*)
    echo "usage: host.sh check | ports [--apply]" >&2
    exit 1
    ;;
esac
