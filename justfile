# Local commands. Decided by ticket 13.
# Tools come from .mise.toml -- run `mise install` once.

set shell := ["bash", "-euo", "pipefail", "-c"]

export SOPS_AGE_KEY_FILE := justfile_directory() / "age.key"

# List the available recipes
default:
    @just --list

# Edit a Stack's encrypted secrets, creating the file if it does not exist
secret stack:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ ! -f "$SOPS_AGE_KEY_FILE" ]]; then
        echo "no age.key at $SOPS_AGE_KEY_FILE -- restore it from KeePassXC"
        exit 1
    fi
    # bootstrap is not a Stack -- Komodo cannot deploy itself -- but it holds
    # secrets under the same convention. Ticket 11.
    if [[ "{{ stack }}" == bootstrap ]]; then
        dir=bootstrap
    else
        dir="stacks/{{ stack }}"
    fi
    if [[ ! -d "$dir" ]]; then
        echo "no such Stack: $dir"
        exit 1
    fi
    sops "$dir/secrets.sops.env"

# Put Komodo on the box and this repo into Komodo, idempotently -- pass --apply
bootstrap *args:
    bash scripts/bootstrap.sh {{ args }}

# Deliver a real notification through every Alerter, to prove the path. Ungated
alert-test:
    bash scripts/komodo.sh alert-test

# Reconcile the box now, rather than waiting for the 15-minute poll. Ungated
reconcile:
    bash scripts/komodo.sh reconcile

# Destroy one Stack's containers and build them again -- pass --apply to commit
redeploy stack *args:
    bash scripts/komodo.sh redeploy {{ stack }} {{ args }}

# Ask the box who actually dials each declared host port -- ticket 31
ports-audit:
    bash scripts/ports.sh

# Report ownership and modes across the shared trees
permissions-audit:
    bash scripts/permissions.sh audit

# Normalise ownership and modes to 99:100 / 775 / 664 -- pass --apply to commit
permissions *args:
    bash scripts/permissions.sh apply {{ args }}

# Diff the box's ident.cfg against the snapshot, and assert the keys of ticket 42
host-check:
    bash scripts/host.sh check

# Move the Unraid GUI onto the snapshot's ports -- pass --apply to commit
host-ports *args:
    bash scripts/host.sh ports {{ args }}

# Free a container from unraid's Docker tab so a Stack can take over -- pass --apply to commit
adopt container *args:
    bash scripts/adopt.sh {{ container }} {{ args }}

# List tracker answers whose shelf life has run out -- ticket 40
revisits:
    bash scripts/check-revisits.sh

# Check exposure, probes, compose files, shell scripts and Dockerfiles
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob

    bash scripts/check-exposure.sh
    bash scripts/check-probes.sh
    bash scripts/check-secrets-mode.sh
    # Advisory -- see the script. Needs no tooling, so it runs before the slow
    # checks and its line is not buried under docker's warnings.
    bash scripts/check-revisits.sh

    for compose in stacks/*/compose.yaml; do
        docker compose --env-file common.env --file "$compose" config --quiet
    done
    # bootstrap has its own env, and is never reconciled -- but an unvalidated
    # compose file in git is exactly what this recipe exists to catch.
    docker compose --env-file bootstrap/compose.env \
        --file bootstrap/compose.yaml config --quiet
    echo "compose ok"

    scripts=(scripts/*.sh)
    if ((${#scripts[@]})); then
        shellcheck "${scripts[@]}"
        echo "shell ok"
    fi

    dockerfiles=(stacks/*/Dockerfile)
    if ((${#dockerfiles[@]})); then
        hadolint "${dockerfiles[@]}"
        echo "dockerfiles ok"
    fi

# Confirm every encrypted file decrypts with the local key
verify-secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob

    if [[ ! -f "$SOPS_AGE_KEY_FILE" ]]; then
        echo "no age.key at $SOPS_AGE_KEY_FILE -- restore it from KeePassXC"
        exit 1
    fi

    encrypted=(stacks/*/secrets.sops.env bootstrap/secrets.sops.env)
    if ((!${#encrypted[@]})); then
        echo "no encrypted files yet"
        exit 0
    fi
    for f in "${encrypted[@]}"; do
        sops --decrypt "$f" >/dev/null
        echo "ok  $f"
    done
