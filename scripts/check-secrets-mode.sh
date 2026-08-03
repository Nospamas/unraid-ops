#!/usr/bin/env bash
# A decrypt in `pre_deploy` must create its plaintext 0600. Ticket 19.
#
# `sops -d ... > secrets.env` is a plain redirect, so the mode is 0666 masked by
# Periphery's umask -- which is 0022, giving a world-readable 0644 plaintext.
# The fix is the subshell umask rather than a chmod afterwards: it closes the
# window in which the file exists at 0644 rather than reopening it a moment
# later.
#
# Only the redirect form is caught. A decrypt written some other way is not
# wrong, but it is also not something this check can reason about -- add it
# here when one appears.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

fail=0

while IFS=: read -r file line text; do
    [[ -z "$file" ]] && continue
    if [[ ! "$text" =~ umask ]]; then
        echo "$file:$line: decrypt writes plaintext without a umask"
        echo "    ${text#"${text%%[![:space:]]*}"}"
        fail=1
    fi
done < <(grep -rn 'sops -d .*>' --include='komodo.toml' stacks/ || true)

if ((fail)); then
    cat <<'EOF'

a bare redirect creates secrets.env 0644 -- world-readable in a tree that is
also world-writable at the top. write it as:

    (umask 077; sops -d secrets.sops.env > secrets.env)
EOF
    exit 1
fi

echo "secrets mode ok"
