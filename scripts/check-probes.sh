#!/usr/bin/env bash
# Every fronted Service is probed. Decided by ticket 44.
#
# A service added by following adding-a-service.md used to land unmonitored: the
# probe was documented only in that file's Traps section, which is where a reader
# goes once something has already gone wrong. [35] got a probe because its ticket
# said to, not because the routine asked for one.
#
# Moving the prose earlier would not have fixed it. **A missing probe has no
# failure signature** -- nothing is down, nothing 404s, the status page simply
# never mentions the service. That is the asymmetry this check exists for, and
# it is why the reverse direction is deliberately not checked: a *stale* probe,
# left behind after a service is removed, fails loudly on its own.
#
# The check is file-only. It compares the `caddy:` hostnames in stacks/*/
# compose.yaml against the endpoint URLs in stacks/gatus/conf/config.yaml, and
# issues no request -- a lint that reached the box would fail in CI, and would
# report "the service is down right now" as "the repo is broken".
#
# There is no opt-out key. Every fronted Service passes today, ntfy included
# [44], and a service that genuinely should not be probed is a conversation, not
# a flag -- the same line this repo takes on `caddy.import: internal`.
#
# Probes with no `caddy:` label are not this script's business: `komodo`,
# `unraid` and `status` are Caddyfile blocks [29], and the vpn, DNS and home-ops
# probes front nothing.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config="$root/stacks/gatus/conf/config.yaml"

if [[ ! -f "$config" ]]; then
    echo "FAIL      no gatus config at stacks/gatus/conf/config.yaml"
    exit 1
fi

# Hosts, not whole URLs -- tautulli and bazarr probe a path below the root [35,
# 36], so a hostname is the only part that can be matched against a label.
# A yq error is fatal rather than an empty result, which would pass everything.
if ! probed="$(yq -r '.endpoints // [] | .[] | .url // ""' "$config" \
    | sed -E 's#^[a-zA-Z][a-zA-Z0-9+.-]*://##; s#/.*##; s#:[0-9]+$##')"; then
    echo "FAIL      could not parse stacks/gatus/conf/config.yaml"
    exit 1
fi

declare -A has_probe=()
while IFS= read -r host; do
    [[ -n "$host" ]] && has_probe["$host"]=1
done <<<"$probed"

# Labels are read in both compose forms, for check-exposure.sh's reason: the
# check must not be sidestepped by reformatting the file.
read -r -d '' query <<'YQ' || true
.services // {} | to_entries[] | .key as $service | (.value.labels // {}) |
  ((select(tag == "!!map") | to_entries[] | select(.key == "caddy") | [$service, (.value | tostring)]),
   (select(tag == "!!seq") | .[] | select(test("^caddy=")) | [$service, sub("^caddy="; "")])
  ) | @tsv
YQ

failed=0
fronted=0

shopt -s nullglob
for compose in "$root"/stacks/*/compose.yaml; do
    stack="$(basename "$(dirname "$compose")")"

    if ! parsed="$(yq -r "$query" "$compose")"; then
        echo "FAIL      ${stack}: could not parse compose.yaml"
        failed=1
        continue
    fi

    while IFS=$'\t' read -r service hostname; do
        [[ -z "${hostname:-}" ]] && continue
        fronted=$((fronted + 1))
        if [[ -z "${has_probe[$hostname]:-}" ]]; then
            echo "FAIL      ${stack}/${service} (${hostname}) is fronted and has no gatus probe"
            failed=1
        fi
    done <<<"$parsed"
done

if ((failed)); then
    echo
    echo "See docs/adding-a-service.md step 7b -- the endpoint and the status are"
    echo "both choices, and the status is measured against the box, not assumed."
    exit 1
fi

echo "probes ok -- ${fronted} fronted service(s), all probed"
