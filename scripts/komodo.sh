#!/usr/bin/env bash
# Drives Komodo Core's API from a laptop clone. Ticket 08.
#
# Core takes the admin password directly at /auth/login -- there is no API key
# -- and that password is already in bootstrap/secrets.sops.env, which this
# clone can decrypt. So this needs no secret the repo does not already have,
# which is what ticket 13 declined a `just reconcile` recipe over.
#
# The request bodies are read out of komodo/sync.toml, so it stays the one
# description of the sync.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# compose.env holds Core's LAN address, which is right when this runs on the
# box. A laptop off that LAN overrides it in .mise.toml.
host="${KOMODO_HOST:-$(sed -n 's/^KOMODO_HOST=//p' "$root/bootstrap/compose.env")}"
jwt=""

login() {
    local creds user pass
    creds="$(sops --decrypt "$root/bootstrap/secrets.sops.env")"
    user="$(printf '%s\n' "$creds" | sed -n 's/^KOMODO_INIT_ADMIN_USERNAME=//p')"
    pass="$(printf '%s\n' "$creds" | sed -n 's/^KOMODO_INIT_ADMIN_PASSWORD=//p')"
    # Built with jq, not hand-quoted: five wrong passwords lock the account.
    jwt="$(jq -n --arg u "$user" --arg p "$pass" \
        '{type:"LoginLocalUser",params:{username:$u,password:$p}}' |
        curl -fsS -X POST -H 'Content-Type: application/json' -d @- \
            "$host/auth/login" | jq -r '.data.jwt')"
    if [[ -z "$jwt" || "$jwt" == null ]]; then
        echo "login to $host failed" >&2
        exit 1
    fi
}

api() {
    curl -fsS -X POST \
        -H "Authorization: Bearer $jwt" \
        -H 'Content-Type: application/json' \
        -d "$2" "$host/$1"
}

sync_name() {
    yq -p toml -o json -r '.resource_sync[0].name' "$root/komodo/sync.toml"
}

# Out-of-band: nothing else ever creates the ResourceSync, so running this is
# itself the decision. Dry-run by default, per ticket 27.
cmd_bootstrap() {
    local apply=0 name params exists=0
    case "${1:-}" in
    --apply) apply=1 ;;
    "") ;;
    *)
        echo "usage: komodo.sh bootstrap [--apply]" >&2
        exit 1
        ;;
    esac

    name="$(sync_name)"
    login

    if api read '{"type":"ListResourceSyncs","params":{}}' |
        jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null; then
        exists=1
        echo "  sync '$name' exists"
    else
        echo "* sync '$name' is missing -- would be created from komodo/sync.toml"
    fi
    echo "  RunSync would then push komodo/ and stacks/ onto Komodo's resources"

    if ((!apply)); then
        echo
        if ((exists)); then
            echo "dry run -- nothing was changed. the sync is already there, so this"
            echo "is step 8 of a rebuild you have already done; reconcile runs the"
            echo "sync every 15 minutes on its own."
        else
            echo "dry run -- nothing was changed."
        fi
        echo "to go ahead:  just bootstrap --apply"
        return
    fi

    if ((!exists)); then
        params="$(yq -p toml -o json '.resource_sync[0]' "$root/komodo/sync.toml")"
        api write "$(jq -n --argjson p "$params" \
            '{type:"CreateResourceSync",params:$p}')" >/dev/null
        echo "created sync '$name'"
    fi

    api execute "$(jq -n --arg n "$name" \
        '{type:"RunSync",params:{sync:$n}}')" >/dev/null
    echo "ran sync '$name' -- komodo/ and stacks/ are now declared to Komodo"
}

get_update() {
    api read "$(jq -n --arg i "$1" '{type:"GetUpdate",params:{id:$i}}')"
}

await_update() {
    local _
    for _ in $(seq 60); do
        [[ "$(get_update "$1" | jq -r '.status')" == Complete ]] && return
        sleep 5
    done
}

# Komodo renders log text as HTML, and a failed stage reports only the id of the
# nested update holding the actual error.
show_update() {
    local update stage
    update="$(get_update "$1")"
    printf '%s\n' "$update" |
        jq -r '.logs[] | "\(.stage): \(if .success then "ok" else "FAILED" end)",
                 (select(.success | not) | (.stdout, .stderr)
                  | select(. != null and . != "") | split("\n")[] | "  | \(.)")' |
        sed -e 's/<[^>]*>//g' -e "s/^/${2}/"

    for stage in $(printf '%s\n' "$update" |
        jq -r '.logs[] | select(.success | not) | (.stdout, .stderr) // ""' |
        grep -o '/updates/[0-9a-f]\{24\}' | sed 's|.*/||' | sort -u); do
        show_update "$stage" "${2}    "
    done
}

# A Procedure cannot be updated while it is running, and `reconcile` runs the
# sync that would update it -- so a change to komodo/procedures.toml can only be
# applied by a RunSync outside the Procedure. Ticket 16.
cmd_sync() {
    local id
    login
    id="$(api execute "$(jq -n --arg n "$(sync_name)" \
        '{type:"RunSync",params:{sync:$n}}')" |
        jq -r '._id."$oid" // .id // empty')"
    if [[ -z "$id" ]]; then
        echo "sync did not return an update id" >&2
        exit 1
    fi
    echo "sync started ($id)"
    await_update "$id"
    show_update "$id" "  "
    get_update "$id" | jq -e '.success' >/dev/null
}

cmd_reconcile() {
    local id
    login
    # Execute responses serialize the id raw; reads return it flattened.
    id="$(api execute '{"type":"RunProcedure","params":{"procedure":"reconcile"}}' |
        jq -r '._id."$oid" // .id // empty')"
    if [[ -z "$id" ]]; then
        echo "reconcile did not return an update id" >&2
        exit 1
    fi
    echo "reconcile started ($id)"
    await_update "$id"
    show_update "$id" "  "
    get_update "$id" | jq -e '.success' >/dev/null
}

case "${1:-}" in
    bootstrap)
        shift
        cmd_bootstrap "$@"
        ;;
    sync) cmd_sync ;;
    reconcile) cmd_reconcile ;;
    *)
        cat >&2 <<'EOF'
usage: komodo.sh <command>

  bootstrap [--apply]   create the ResourceSync Komodo cannot create for itself,
                        and run it. Dry run without --apply.
  sync                  run the ResourceSync alone. The only way to apply a
                        change to komodo/procedures.toml.
  reconcile             run the reconcile Procedure now, rather than waiting for
                        the poll. Ungated -- the cron does this anyway.
EOF
        exit 1
        ;;
esac
