# 02 — Choose the reconcile mechanism

Type: research
Status: open

## Question

How does the unraid box get changes out of this repo and apply them?

**Incumbency is not evidence.** Ticket 01 found Portainer already on the box,
running a hand-made qbittorrent+gluetun stack. The human has ruled explicitly
that this must *not* weigh in Portainer's favour here — judge it on the five
criteria below like any other candidate, and be willing to conclude the stack
should move off it. What is being kept is qbittorrent and gluetun, not the thing
currently deploying them.

**Hard constraint from [01](01-inventory-running-containers.md): there is no
compose implementation on the box.** Unraid 7.2.0 ships Docker 27.5.1 with no
`docker compose` plugin, and neither the Compose Manager nor the User Scripts
plugin is installed. Every candidate must therefore either carry its own compose
implementation inside a container, or install one somewhere that survives a
reboot — unraid's OS lives in RAM and rebuilds from `/boot`. This bites the
"plain `git pull` + `docker compose up -d`" option hardest.

**Also settle Portainer's fate.** It currently runs two stacks (`plex`, and
`gluetun`+`qbittorrent`) from `/mnt/user/appdata/portainer/compose/`. Whatever
wins, say what happens to those two stacks and whether Portainer is removed,
kept as a read-only UI, or kept as the mechanism.

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
