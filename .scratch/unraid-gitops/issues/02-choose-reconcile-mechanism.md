# 02 — Choose the reconcile mechanism

Type: research
Status: open

## Question

How does the unraid box get changes out of this repo and apply them?

Compare, as a written asset in the repo:

- **Komodo** — purpose-built GitOps for Docker hosts, watches a repo, applies
  compose stacks, has a UI.
- **Dockge** — lighter compose manager, git support is thinner.
- **Portainer git stacks** — polls a repo and redeploys on change.
- **Unraid Compose Manager plugin** — native to the platform, weakest git story.
- **Plain `git pull` + `docker compose up -d`** driven by an unraid user script
  or systemd timer — no extra platform, you own the glue.

Judge each against the constraints this map has already fixed:

1. **Adoption without data loss** — can it take over containers that unraid's
   Docker tab currently manages, keeping their appdata mounts intact? What
   happens to the unraid UI's view of a container once compose owns it?
2. **Secret decryption at apply time** — the secrets decision
   (ticket 03) depends on this. Does the tool support an encrypted-at-rest
   secrets file, a pre-apply hook, or only plain `.env`?
3. **Push vs poll** — does a `git push` trigger it (webhook), or does it poll on
   an interval? The destination says "reconciles automatically"; a 5-minute poll
   satisfies that, a manual button does not.
4. **Survives an unraid reboot** — unraid's OS lives in RAM and rebuilds from
   `/boot` on boot. Anything installed outside a Docker container or a plugin
   will not persist. Confirm how each option survives.
5. **Drift behaviour** — what it does when a container is changed by hand.

The answer names the choice and the reason, not a survey.
