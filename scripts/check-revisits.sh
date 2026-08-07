#!/usr/bin/env bash
# Report tracker issues whose answer has a shelf life -- `status: revisitable`
# plus a `revisit:` date. Advisory: it never fails, because an aging answer is
# not a broken repo and blocking every push on one would only teach people to
# ignore it. Ticket 40.
set -euo pipefail
shopt -s nullglob

today=$(date +%s)
due=()
pending=()

for issue in .scratch/*/issues/*.md; do
    # Frontmatter only -- the body may discuss revisits without declaring one.
    frontmatter=$(awk 'NR==1 && $0!="---" {exit} NR>1 && $0=="---" {exit} NR>1' "$issue")

    status=$(printf '%s\n' "$frontmatter" | sed -n 's/^status:[[:space:]]*//p')
    [[ "$status" == "revisitable" ]] || continue

    date_field=$(printf '%s\n' "$frontmatter" | sed -n 's/^revisit:[[:space:]]*//p')
    title=$(printf '%s\n' "$frontmatter" | sed -n 's/^title:[[:space:]]*//p')

    if [[ -z "$date_field" ]]; then
        echo "revisitable with no revisit date: $issue" >&2
        continue
    fi

    when=$(date -d "$date_field" +%s 2>/dev/null) || {
        echo "unparseable revisit date in $issue: $date_field" >&2
        continue
    }

    if ((when <= today)); then
        due+=("$date_field  $title -- $issue")
    else
        pending+=("$date_field  $title")
    fi
done

if ((${#due[@]})); then
    echo "REVISIT DUE (${#due[@]}):"
    printf '  %s\n' "${due[@]}"
elif ((${#pending[@]})); then
    # Sorted so the nearest date is the one reported.
    next=$(printf '%s\n' "${pending[@]}" | sort | head -1)
    echo "revisits ok -- next: $next"
else
    echo "revisits ok -- none declared"
fi
