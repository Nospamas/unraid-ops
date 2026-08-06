#!/usr/bin/env bash
# Who actually dials each declared host port. Ticket 31.
#
# `x-host-port` is a sentence, and check-exposure.sh only asserts the sentence
# exists. Ticket 30 found two of them false -- each true when written, each
# decayed since -- and acting on one would have deleted the probe that catches
# ticket 06's hazard. So this asks the box rather than the file.
#
# Two sources, because neither is sufficient alone:
#
#   nat DOCKER packet counters -- cumulative since the container started, so
#       "nothing has ever dialled this" is answerable. Blind to loopback: nat
#       OUTPUT jumps to DOCKER only for ! 127.0.0.0/8, so a 127.0.0.1 bind is
#       served by userland docker-proxy and its counter is structurally 0.
#   ss established -- says who, but only right now. A reader that dials once a
#       minute is usually invisible to it.
#
# Read-only, so ungated (ticket 27). It reports; it decides nothing.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tower="${TOWER_SSH:-root@tower}"

read -r -d '' query <<'YQ' || true
.services // {} | to_entries[] | .key as $service |
  (.value["x-host-port"] // "-- none declared" | tostring | sub("\n"; " ")) as $claim |
  (.value.ports // [])[] | [$service, (. | tostring), $claim] | @tsv
YQ

remote="$(ssh "$tower" '
    echo "#nat"
    iptables -t nat -L DOCKER -v -n
    echo "#estab"
    ss -tnH state established
')"

nat="$(sed -n '/^#nat$/,/^#estab$/p' <<<"$remote")"
estab="$(sed -n '/^#estab$/,$p' <<<"$remote")"

# Cumulative packets through the DNAT rule for this bind and port, or empty if
# there is no such rule.
counter() {
    local proto="$1" bind="$2" port="$3" dest="$2"
    [[ "$bind" == "0.0.0.0" ]] && dest="0.0.0.0/0"
    awk -v proto="$proto" -v dest="$dest" -v port="$port" \
        '$4 == proto && $9 == dest && $0 ~ ("dpt:" port "([^0-9]|$)") { print $1; exit }' <<<"$nat"
}

# Where the peers of the connections on this port sit. Ordered so the answer
# reads as a sentence rather than a table.
peers() {
    local bind="$1" port="$2"
    awk -v bind="$bind" -v port="$port" '
        {
            split($3, l, ":"); split($4, p, ":")
            if (l[length(l)] != port) next
            if (bind != "0.0.0.0" && $3 !~ ("^" bind ":")) next
            peer = p[1]
            if (peer ~ /^127\./) where = "loopback"
            else if (peer ~ /^192\.168\.1\./) where = "rb-lan"
            else if (peer ~ /^100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\./) where = "tailnet"
            else if (peer ~ /^172\.(1[6-9]|2[0-9]|3[01])\./) where = "docker"
            else where = "WAN"
            n[where]++; total++
        }
        END {
            if (!total) { print "0 established"; exit }
            out = total " established --"
            for (w in n) out = out " " n[w] " " w
            print out
        }' <<<"$estab"
}

shopt -s nullglob
found=0
for compose in "$root"/stacks/*/compose.yaml; do
    stack="$(basename "$(dirname "$compose")")"

    while IFS=$'\t' read -r service spec claim; do
        [[ -z "$service" ]] && continue
        found=$((found + 1))

        proto="tcp"
        [[ "$spec" == */* ]] && proto="${spec##*/}"
        hostpart="${spec%%/*}"

        IFS=':' read -r -a parts <<<"$hostpart"
        if ((${#parts[@]} >= 3)); then
            bind="${parts[0]}" port="${parts[1]}"
        else
            bind="0.0.0.0" port="${parts[0]}"
        fi

        echo "${stack}/${service}  ${port}/${proto}  bind ${bind}"
        echo "  claim:   ${claim}"

        if [[ "$bind" == 127.* ]]; then
            echo "  dialled: -- loopback bind, docker-proxy serves it and the counter cannot see it"
        else
            pkts="$(counter "$proto" "$bind" "$port")"
            if [[ -z "$pkts" ]]; then
                echo "  dialled: -- no DNAT rule; the container may not be running"
            elif [[ "$pkts" == 0 ]]; then
                echo "  dialled: 0 packets since the container started -- nothing has used this port"
            else
                echo "  dialled: ${pkts} packets since the container started"
            fi
        fi

        if [[ "$proto" == "udp" ]]; then
            echo "  now:     -- udp, no connection state to sample"
        else
            echo "  now:     $(peers "$bind" "$port")"
        fi
        echo
    done < <(yq -r "$query" "$compose")
done

echo "${found} declared host port(s). A claim naming a reader that has never dialled is the"
echo "decay ticket 30 found -- check who dials the port, not what the key says."
