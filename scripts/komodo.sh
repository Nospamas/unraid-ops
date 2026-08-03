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

# Komodo renders logs as HTML, and nests the real error in another update.
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

run() {
    local id
    # Execute responses serialize the id raw; reads return it flattened.
    id="$(api execute "$2" | jq -r '._id."$oid" // .id // empty')"
    if [[ -z "$id" ]]; then
        echo "$1 did not return an update id" >&2
        exit 1
    fi
    echo "$1 started ($id)"
    await_update "$id"
    show_update "$id" "  "
    get_update "$id" | jq -e '.success' >/dev/null
}

cmd_reconcile() {
    login
    # Bare first: Komodo will not update a Procedure while it is running.
    run sync "$(jq -n --arg n "$(sync_name)" \
        '{type:"RunSync",params:{sync:$n}}')"
    run reconcile '{"type":"RunProcedure","params":{"procedure":"reconcile"}}'
}

# Destroy a Stack's containers and build them again. Ticket 21.
#
# `reconcile` cannot do this: DeployStackIfChanged deploys on a *changed*
# config hash, and the container this exists to repair has an unchanged one.
# A deploy that fails at docker's networking stage leaves the container Up with
# no networks and no published ports, and neither a restart nor the next
# reconcile notices -- so the loop reports success over a container serving
# nothing. Recreating is the only cure.
#
# Named Stacks only, never a pattern: this is the unconditional deploy the
# reconcile Procedure is deliberately not allowed to do.
cmd_redeploy() {
    local stack apply=0
    stack="${1:-}"
    case "${2:-}" in
    --apply) apply=1 ;;
    "") ;;
    *) stack="" ;;
    esac
    if [[ -z "$stack" ]]; then
        echo "usage: komodo.sh redeploy <stack> [--apply]" >&2
        exit 1
    fi
    if [[ ! -d "$root/stacks/$stack" ]]; then
        echo "no such Stack: stacks/$stack" >&2
        exit 1
    fi

    echo "  would destroy and rebuild the containers of Stack '$stack'"
    echo "  appdata binds are untouched; anything written inside the container is not"

    if ((!apply)); then
        echo
        echo "dry run -- nothing was changed. re-run with:  just redeploy $stack --apply"
        return
    fi

    login
    run "destroy $stack" "$(jq -n --arg s "$stack" \
        '{type:"DestroyStack",params:{stack:$s}}')"
    run "deploy $stack" "$(jq -n --arg s "$stack" \
        '{type:"DeployStack",params:{stack:$s}}')"
}

case "${1:-}" in
    bootstrap)
        shift
        cmd_bootstrap "$@"
        ;;
    reconcile) cmd_reconcile ;;
    redeploy)
        shift
        cmd_redeploy "$@"
        ;;
    *)
        cat >&2 <<'EOF'
usage: komodo.sh <command>

  bootstrap [--apply]   create the ResourceSync Komodo cannot create for itself,
                        and run it. Dry run without --apply.
  reconcile             sync the resources, then run the reconcile Procedure,
                        rather than waiting for the poll. Ungated -- the cron
                        does this anyway.
  redeploy <stack>      destroy one Stack's containers and build them again,
                        for the deploy that left them broken with an unchanged
                        config hash. Dry run without --apply.
EOF
        exit 1
        ;;
esac
