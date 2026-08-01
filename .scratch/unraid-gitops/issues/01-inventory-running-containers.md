# 01 — Inventory the containers already running on the box

Type: task
Status: open

## Question

Nothing here is a decision — but every decision downstream is blocked until we
can see what we are adopting. Capture the current state of the unraid box as a
committed markdown asset:

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
lean on: appdata root, the box's LAN address, and which services are already
VPN-routed.
