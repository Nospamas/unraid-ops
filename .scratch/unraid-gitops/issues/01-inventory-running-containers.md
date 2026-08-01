# 01 — Inventory the containers already running on the box

Type: task (HITL)
Status: open

## Question

Nothing here is a decision — but every decision downstream is blocked until we
can see what we are adopting. Capture the current state of the unraid box as a
committed markdown asset.

**HITL**: there is no agent access to the box — the human drives it through the
Web UI over tailscale (see the map's Box access note). So this ticket is worked
as a hand-off: the session writes a copy-pasteable command checklist, the human
runs it and pastes the output back, and the session turns that into the asset.
Write the checklist to be run in one sitting, in the Web UI's terminal, with the
commands ordered so the output can be pasted back in one block.

Capture:

- Every running container: name, image, exact tag, restart policy.
- Port mappings, and which are exposed to the LAN.
- Every volume mount, with the host path on the array (`/mnt/user/...`) and
  the container path — especially the appdata directory for each service.
- Environment variables, with secret-looking values redacted to a placeholder
  and noted as "needs a secret" rather than copied.
- Which network each container is on, and whether any already route through a
  VPN container.
- The unraid docker template XML for each service
  (`/boot/config/plugins/dockerMan/templates-user/*.xml`) — these hold the
  original Community Apps definitions and are the raw material for translating
  into compose.
- Unraid version, Docker version, and whether the Compose Manager plugin is
  installed.

The answer records the asset's path plus the handful of facts later tickets will
lean on: appdata root, the box's LAN address, its tailscale hostname (ticket 05
will care), and which services are already VPN-routed.
