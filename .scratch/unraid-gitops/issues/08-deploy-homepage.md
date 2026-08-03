# 08 — Deploy homepage from the repo

Type: task
Status: open
Assignee: Nospamas
Blocked by: 03, 07, 10, 11

## Question

The proving case. Stand homepage up under the repo's control end to end, so that
a `git push` changes what the dashboard shows.

**The mechanism is Komodo** ([02](02-choose-reconcile-mechanism.md)), installed
by [11](11-stand-up-komodo.md) and pointed at the remote from
[10](10-publish-repo-to-remote.md) — so by the time this ticket runs, the loop
exists and is reconciling nothing. All this ticket adds is the first thing for
it to reconcile.

**Reconcile is poll, not webhook.** Per 02, a GitHub webhook needs an inbound
path the box does not have until [05](05-remote-access.md); the loop is a Komodo
Procedure on a cron schedule running `BatchDeployStackIfChanged`. So "without a
manual step" means *within the poll interval*, not *instantly* — set the
interval deliberately and record it.

**This is a greenfield deploy, not a migration.**
[01](01-inventory-running-containers.md) found no homepage container, no
`/mnt/user/appdata/homepage`, and no homepage YAML anywhere on the box. That
removes all adoption risk from the proving case — nothing here can lose data —
so what it actually proves is the reconcile loop and the ticket 07 layout, in
isolation. Good: a failure here is unambiguous.

Homepage is the right first service because git owns *everything* about it — its
config is plain YAML files (`settings.yaml`, `services.yaml`, `bookmarks.yaml`,
`widgets.yaml`, `docker.yaml`), so it exercises both halves of the reconcile: the
container definition *and* the app's own config.

Do:

- Write homepage's container definition using the layout from ticket 07.
- Decide where its appdata goes — `/mnt/user/appdata/homepage` does not exist
  yet, so this is the one service whose on-disk layout is a free choice.
- Pull the *arr API keys out of each service's `/config/config.xml` (per
  [01](01-inventory-running-containers.md) they are not environment variables,
  so nothing has captured them yet) and feed them through ticket 03's mechanism.
  Homepage is the only consumer.
- Port the config files across. The existing home-ops versions at
  `~/home-ops/kubernetes/apps/self-hosted/homepage/app/config/` are a good
  starting shape, but the `kubernetes.yaml` provider and every
  `*.svc.cluster.local` widget URL have no meaning here — the docker provider
  and container names replace them.
- Point `href`s at the hostnames from ticket 04. Widgets must cover all eight
  in-scope services, not the destination's five.
- Push a change and confirm the box picks it up without a manual step.

The answer records what the reconcile loop actually did on push, how long it
took, and anything about the layout that ticket 07 got wrong — that feedback is
what graduates the remaining service migrations out of the fog.

## Settled by [07](07-repo-layout-and-conventions.md)

The layout this ticket was waiting on exists — see
[docs/repo-layout.md](../../../docs/repo-layout.md) and the checklist in
[docs/adding-a-service.md](../../../docs/adding-a-service.md). For homepage
specifically:

- `stacks/homepage/` holds `komodo.toml`, `compose.yaml`, `config/` and
  `secrets.sops.env` (the *arr API keys).
- **`config/` is the one place git owns a service's own settings outright**,
  because homepage's config is plain YAML files rather than a database. That is
  what makes homepage the proving case: a `git push` that changes
  `config/services.yaml` visibly changes the dashboard.
- Homepage is fronted like anything else — `caddy: home.rbrb.in` plus
  `caddy.import: internal`, and `scripts/check-exposure.sh` will fail the repo if
  the second label is missing.

This ticket is the **first end-to-end exercise of the add-a-service checklist**.
If a step in it turns out to need a decision rather than a keystroke, that is a
defect in 07's answer — record it here and amend
[docs/adding-a-service.md](../../../docs/adding-a-service.md) rather than
deciding it ad hoc.
