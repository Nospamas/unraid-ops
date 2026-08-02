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
    if [[ ! -d "stacks/{{ stack }}" ]]; then
        echo "no such Stack: stacks/{{ stack }}"
        exit 1
    fi
    sops "stacks/{{ stack }}/secrets.sops.env"

# Check exposure, compose files, shell scripts and Dockerfiles
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    shopt -s nullglob

    bash scripts/check-exposure.sh

    for compose in stacks/*/compose.yaml; do
        docker compose --env-file common.env --file "$compose" config --quiet
    done
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

    encrypted=(stacks/*/secrets.sops.env)
    if ((!${#encrypted[@]})); then
        echo "no encrypted files yet"
        exit 0
    fi
    for f in "${encrypted[@]}"; do
        sops --decrypt "$f" >/dev/null
        echo "ok  $f"
    done
