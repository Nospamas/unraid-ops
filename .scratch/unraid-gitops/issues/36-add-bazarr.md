# 36 — Add bazarr

Type: task
Status: open
Blocked by: —

## Question

Subtitles for sonarr and radarr. This is the routine in
[adding-a-service.md](../../../docs/adding-a-service.md) with no decision in it —
if a step needs one, the conventions are wrong and it goes against
[conventions.md](../../../docs/conventions.md) rather than being decided here.

### The one thing to get right

**Bazarr's media binds mirror sonarr's and radarr's exactly**, so bazarr sees
each file at the path the *arr report and no path mapping is needed:

```yaml
    volumes:
      - ${APPDATA}/bazarr:/config
      - ${MEDIA}/tv:/tv          # matches stacks/sonarr/compose.yaml
      - ${MEDIA}/movies:/movies  # matches stacks/radarr/compose.yaml
```

Otherwise: linuxserver image pinned `version@digest`, `shared`,
`bazarr.rbrb.in`, `caddy.import: internal`, port 6767, no host port. Bazarr
addresses the *arr as `http://sonarr:8989` and `http://radarr:7878` — container
names, per the **Addressing** rule ([26](26-host-state-scope.md)).

### No secret

Provider accounts are **rb's**, created and configured by him in bazarr's own UI
after this deploys. Nothing encrypted, no seventh secret, no provider decision on
this ticket. Bazarr ships inert and that is correct.

Its language profiles, scoring and provider list live in appdata and are **not
reconciled** — [CONTEXT.md](../../../CONTEXT.md)'s line, homepage being the sole
exception. The map carries as fog whether that should hold once there is tuning
worth losing.

### Do not forget

- **Add a gatus probe** to [stacks/gatus/conf/config.yaml](../../../stacks/gatus/conf/config.yaml).
  The routine never tells you to — it appears only in that doc's Traps section.
  Bazarr with no provider configured may not answer 200; the condition is the
  service's **actual** unauthenticated status.
- **Add `bazarr` to the `BatchDeployStackIfChanged` pattern** in
  [komodo/procedures.toml](../../../komodo/procedures.toml), then `just reconcile` —
  the cron cannot apply that edit.
- **One Stack at a time** — do not batch with [35](35-add-tautulli.md).
- **A green reconcile is not a running service.** Check the workload.

## Hand-offs

- **rb** signs up for a subtitle provider (OpenSubtitles.com or similar) and
  configures providers and language profiles in bazarr's UI. Until he does,
  bazarr runs and downloads nothing.
