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

cmd_bootstrap() {
    local name params
    name="$(sync_name)"
    login

    if api read '{"type":"ListResourceSyncs","params":{}}' |
        jq -e --arg n "$name" 'any(.[]; .name == $n)' >/dev/null; then
        echo "sync '$name' already exists"
    else
        params="$(yq -p toml -o json '.resource_sync[0]' "$root/komodo/sync.toml")"
        api write "$(jq -n --argjson p "$params" \
            '{type:"CreateResourceSync",params:$p}')" >/dev/null
        echo "created sync '$name'"
    fi

    api execute "$(jq -n --arg n "$name" \
        '{type:"RunSync",params:{sync:$n}}')" >/dev/null
    echo "ran sync '$name' -- komodo/ and stacks/ are now declared to Komodo"
}

cmd_reconcile() {
    local id status
    login
    id="$(api execute '{"type":"RunProcedure","params":{"procedure":"reconcile"}}' |
        jq -r '.id')"
    echo "reconcile started ($id)"

    for _ in $(seq 60); do
        status="$(api read "$(jq -n --arg i "$id" \
            '{type:"GetUpdate",params:{id:$i}}')" | jq -r '.status')"
        [[ "$status" == Complete ]] && break
        sleep 5
    done

    api read "$(jq -n --arg i "$id" '{type:"GetUpdate",params:{id:$i}}')" |
        jq -r '"\(.status)  success=\(.success)",
               (.logs[] | "  \(.stage): \(if .success then "ok" else "FAILED" end)")'
}

case "${1:-}" in
    bootstrap) cmd_bootstrap ;;
    reconcile) cmd_reconcile ;;
    *)
        cat >&2 <<'EOF'
usage: komodo.sh <command>

  bootstrap   create the ResourceSync Komodo cannot create for itself, and run it
  reconcile   run the reconcile Procedure now, rather than waiting for the poll
EOF
        exit 1
        ;;
esac
