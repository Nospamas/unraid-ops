#!/usr/bin/env bash
# Every fronted Service declares its exposure. Decided by ticket 07.
#
# A Service carrying a `caddy:` hostname label is reachable through the proxy.
# It must say which kind of reachable:
#
#   caddy.import: internal   -> LAN + tailnet only. The default.
#   x-published: true        -> deliberately internet-facing.
#
# Neither is a failure. Both is a failure, because the intent is unreadable.
# `grep -rn x-published stacks/` is the answer to "what faces the internet".
#
# Labels are read in both compose forms -- the `key: value` map this repo writes
# and the `- key=value` list -- so the check cannot be sidestepped by
# reformatting. A yq error is fatal rather than an empty result, so a file this
# script cannot parse fails the build instead of passing silently.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

read -r -d '' query <<'YQ' || true
.services // {} | to_entries[] | .key as $service | (.value.labels // {}) as $labels |
  ((
    ($labels | select(tag == "!!map") | to_entries[] | [$service, .key, (.value | tostring)]),
    ($labels | select(tag == "!!seq") | .[] | [$service, (sub("=.*"; "")), (sub("^[^=]*=?"; ""))]),
    [$service, "x-published", (.value["x-published"] // "" | tostring)]
  ) | @tsv)
YQ

failed=0
fronted=0

shopt -s nullglob
for compose in "$root"/stacks/*/compose.yaml; do
    stack="$(basename "$(dirname "$compose")")"

    # Not a process substitution: yq must be able to fail the script.
    if ! parsed="$(yq -r "$query" "$compose")"; then
        echo "FAIL      ${stack}: could not parse compose.yaml"
        failed=1
        continue
    fi

    declare -A host=() internal=() published=()
    while IFS=$'\t' read -r service key value; do
        [[ -z "$service" ]] && continue
        case "$key" in
            caddy) host["$service"]="$value" ;;
            caddy.import) internal["$service"]="$value" ;;
            x-published) published["$service"]="$value" ;;
        esac
    done <<<"$parsed"

    for service in "${!host[@]}"; do
        [[ -z "${host[$service]}" ]] && continue
        fronted=$((fronted + 1))

        local_host="${host[$service]}"
        is_internal=$([[ "${internal[$service]:-}" == "internal" ]] && echo yes || echo no)
        is_published=$([[ "${published[$service]:-}" == "true" ]] && echo yes || echo no)

        if [[ "$is_internal" == yes && "$is_published" == yes ]]; then
            echo "FAIL      ${stack}/${service} (${local_host}) declares both caddy.import: internal and x-published: true"
            failed=1
        elif [[ "$is_published" == yes ]]; then
            echo "PUBLISHED ${stack}/${service} (${local_host}) -- internet-facing, deliberately"
        elif [[ "$is_internal" == no ]]; then
            echo "FAIL      ${stack}/${service} (${local_host}) is fronted but declares neither caddy.import: internal nor x-published: true"
            failed=1
        fi
    done
    unset host internal published
done

if ((failed)); then
    echo
    echo "Default-deny violated. See docs/conventions.md, 'Default-deny'."
    exit 1
fi

echo "exposure ok -- ${fronted} fronted service(s)"
