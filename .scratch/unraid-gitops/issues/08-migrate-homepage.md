# 08 — Migrate homepage into the repo

Type: task
Status: open
Blocked by: 03, 07

## Question

The proving case. Bring homepage under the repo's control end to end, so that a
`git push` changes what the dashboard shows.

Homepage is the right first migration because it is the one service where git
owns *everything* — its config is plain YAML files (`settings.yaml`,
`services.yaml`, `bookmarks.yaml`, `widgets.yaml`, `docker.yaml`), so it
exercises both halves of the reconcile: the container definition *and* the
app's own config.

Do:

- Write homepage's container definition using the layout from ticket 07.
- Port the config files across. The existing home-ops versions at
  `~/home-ops/kubernetes/apps/self-hosted/homepage/app/config/` are a good
  starting shape, but the `kubernetes.yaml` provider and every
  `*.svc.cluster.local` widget URL have no meaning here — the docker provider
  and container names replace them.
- Wire the widget API keys through the ticket 03 secrets mechanism.
- Point `href`s at the hostnames from ticket 04.
- Push a change and confirm the box picks it up without a manual step.

The answer records what the reconcile loop actually did on push, how long it
took, and anything about the layout that ticket 07 got wrong — that feedback is
what graduates the remaining service migrations out of the fog.
