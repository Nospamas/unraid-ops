#!/usr/bin/env bash
# Every fronted Service declares its exposure. Decided by ticket 07.
#
# The two keys answer different questions, and a Service can need both [31].
#
#   caddy.import: internal   -> governs the Caddy route: LAN + tailnet only.
#                               The default, and the label that does the work.
#   x-published: <prose>      -> the Service is on the internet, by whatever
#                               path. The value names the path.
#
# A fronted Service must carry at least one, because a `caddy:` hostname with
# neither is a naked vhost nobody meant to leave naked. Both together is plex:
# the Caddy route is guarded and the service is still on the internet, by a
# host port and a router this repo does not own [31].
#
# `grep -rn x-published stacks/` is the answer to "what faces the internet".
# It was wrong for the whole map before 31, because it described the Caddy path
# and plex is exposed by another one.
#
# A Service that publishes a host port must also say who reaches it that way,
# because humans go through Caddy and containers go by name on `shared` --
# anything else is the exception (ticket 26):
#
#   x-host-port: <who reaches this, and why not by hostname>
#
# This is a separate question from x-published: it asks who the port is for,
# not whether the internet can see it. A Service can need both keys.
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
    [$service, "x-published", (.value["x-published"] // "" | tostring)],
    [$service, "x-host-port", (.value["x-host-port"] // "" | tostring | sub("\n"; " "))],
    [$service, "port-count", (.value.ports // [] | length | tostring)]
  ) | @tsv)
YQ

failed=0
fronted=0
ports=0
published_count=0

shopt -s nullglob
for compose in "$root"/stacks/*/compose.yaml; do
    stack="$(basename "$(dirname "$compose")")"

    # Not a process substitution: yq must be able to fail the script.
    if ! parsed="$(yq -r "$query" "$compose")"; then
        echo "FAIL      ${stack}: could not parse compose.yaml"
        failed=1
        continue
    fi

    declare -A host=() internal=() published=() hostport=() portcount=()
    while IFS=$'\t' read -r service key value; do
        [[ -z "$service" ]] && continue
        case "$key" in
            caddy) host["$service"]="$value" ;;
            caddy.import) internal["$service"]="$value" ;;
            x-published) published["$service"]="$value" ;;
            x-host-port) hostport["$service"]="$value" ;;
            port-count) portcount["$service"]="$value" ;;
        esac
    done <<<"$parsed"

    for service in "${!portcount[@]}"; do
        [[ "${portcount[$service]}" == 0 ]] && continue
        ports=$((ports + 1))
        if [[ -z "${hostport[$service]:-}" ]]; then
            echo "FAIL      ${stack}/${service} publishes a host port and declares no x-host-port"
            failed=1
        fi
    done

    # Published is a property of the Service, not of its Caddy route, so this
    # walks every Service rather than the fronted ones [31].
    for service in "${!portcount[@]}"; do
        [[ -z "${published[$service]:-}" ]] && continue
        published_count=$((published_count + 1))
        hostname="${host[$service]:-}"
        guarded=""
        [[ "${internal[$service]:-}" == "internal" ]] && guarded=", Caddy route guarded"
        echo "PUBLISHED ${stack}/${service}${hostname:+ (${hostname}${guarded})} -- ${published[$service]}"
    done

    for service in "${!host[@]}"; do
        [[ -z "${host[$service]}" ]] && continue
        fronted=$((fronted + 1))

        if [[ "${internal[$service]:-}" != "internal" && -z "${published[$service]:-}" ]]; then
            echo "FAIL      ${stack}/${service} (${host[$service]}) is fronted but declares neither caddy.import: internal nor x-published"
            failed=1
        fi
    done
    unset host internal published hostport portcount
done

if ((failed)); then
    echo
    echo "See docs/conventions.md -- 'Default-deny' and 'Addressing'."
    exit 1
fi

echo "exposure ok -- ${fronted} fronted service(s), ${ports} with a host port, ${published_count} published"
