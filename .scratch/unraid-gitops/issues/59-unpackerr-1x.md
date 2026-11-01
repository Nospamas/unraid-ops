---
id: "59"
title: Land unpackerr 1.x
type: task
status: open
description: >
  Renovate's 1.x bump merged with no Stack changes, but 1.x puts /metrics behind
  an API key and drops the container's implicit poll.
touches:
  - stacks/unpackerr/compose.yaml
  - stacks/unpackerr/secrets.sops.env
  - stacks/gatus/compose.yaml
  - stacks/gatus/komodo.toml
  - stacks/gatus/secrets.sops.env
  - stacks/gatus/conf/config.yaml
  - docs/adding-a-service.md
  - docs/conventions.md
---

# 59 — Land unpackerr 1.x

Blocked by: —
Claimed by: Claude session, 2026-11-01

## Question

What does `ghcr.io/unpackerr/unpackerr:v1.0.1` need from this Stack before it
replaces 0.16.1?
