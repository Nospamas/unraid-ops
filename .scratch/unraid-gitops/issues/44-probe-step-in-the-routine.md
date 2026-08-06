---
id: "44"
title: Give the routine its gatus-probe step
type: task
status: open
description: >
  A service added by following adding-a-service.md end to end lands
  unmonitored — the probe appears only in that doc's Traps section, so it is
  read by whoever already knows. Decide whether it becomes a numbered step, and
  what it says about choosing the endpoint and the status.
touches: [docs/adding-a-service.md]
---

# 44 — Give the routine its gatus-probe step

Blocked by: —

## Question

[adding-a-service.md](../../../docs/adding-a-service.md) runs from *make the
directory* to *check it* and never mentions gatus. The probe lives in the
**Traps** section, which is where a reader goes when something has already gone
wrong — so a service added by following the routine end to end is
**unmonitored**, and nothing catches it, because a missing probe has no failure
signature.

[35](35-add-tautulli.md) only added one because the ticket said to.

Decide whether it becomes a numbered step, and if so what it carries — because
the probe is not a copy-paste line:

- **the endpoint is a choice.** Every probe in
  [config.yaml](../../../stacks/gatus/conf/config.yaml) hits `/` except
  tautulli's, which hits `/status` — its root moves between 303, 200 and 302 as
  the setup wizard and the auth setting change, and a probe cannot assert a
  status that appdata governs [35].
- **the status is measured, not assumed** [29]. Six of the ten were not 200.
- **it cannot be measured before the first deploy**, so the step lands after
  step 7 and the routine currently ends at step 8.

Whether the same is owed to the `BatchDeployStackIfChanged` list — which *is* in
the routine, at step 7 — is not in question; it is there and it works.
