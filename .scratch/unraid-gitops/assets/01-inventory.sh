#!/bin/bash
# unraid-ops — ticket 01 inventory probe.
#
# Run in the unraid Web UI terminal. Produces ONE block of output; paste the
# whole thing back. Secret-looking values are redacted before printing, but
# eyeball the output before pasting anyway.
#
#   bash /tmp/01-inventory.sh 2>&1 | tee /tmp/01-inventory.txt
#
# ...or paste the whole file into the terminal.

REDACT() {
  sed -E \
    -e 's/([A-Za-z0-9_]*(PASS|PASSWD|PASSWORD|KEY|TOKEN|SECRET|CRED|PRIVATE|WIREGUARD|APIKEY|AUTH)[A-Za-z0-9_]*)=[^[:space:]]*/\1=<<REDACTED — needs a secret>>/g' \
    -e 's/[A-Fa-f0-9]{32,}/<<REDACTED-HEX>>/g'
}

echo "########## 1. HOST"
cat /etc/unraid-version 2>/dev/null || echo "no /etc/unraid-version"
echo "kernel: $(uname -r)"
docker --version
docker compose version 2>/dev/null || echo "no docker compose plugin"

echo
echo "########## 2. PLUGINS (compose manager? user scripts? tailscale?)"
ls -1 /boot/config/plugins/ 2>/dev/null
echo "--- compose manager projects:"
ls -1 /boot/config/plugins/compose.manager/projects/ 2>/dev/null || echo "compose.manager not installed"
echo "--- user scripts:"
ls -1 /boot/config/plugins/user.scripts/scripts/ 2>/dev/null || echo "user.scripts not installed"

echo
echo "########## 3. NETWORK"
echo "--- host addresses:"
ip -4 addr show 2>/dev/null | grep -E '^[0-9]+:|inet '
echo "--- tailscale:"
if command -v tailscale >/dev/null 2>&1; then
  tailscale status --self=true 2>&1 | head -30
  echo "tailscale hostname: $(tailscale status --json 2>/dev/null | grep -m1 -o '"DNSName":"[^"]*"')"
else
  echo "no tailscale CLI on host (may be running as a container — see container list)"
fi
echo "--- docker networks:"
docker network ls

echo
echo "########## 4. CONTAINER SUMMARY"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}'

echo
echo "########## 5. CONTAINER DETAIL"
for c in $(docker ps -a --format '{{.Names}}'); do
  echo "===== $c"
  docker inspect "$c" --format \
'image:        {{.Config.Image}}
created:      {{.Created}}
restart:      {{.HostConfig.RestartPolicy.Name}}
network_mode: {{.HostConfig.NetworkMode}}
networks:     {{range $k,$v := .NetworkSettings.Networks}}{{$k}}(ip={{$v.IPAddress}}) {{end}}
ports:        {{range $p,$b := .HostConfig.PortBindings}}{{$p}}->{{range $b}}{{.HostIp}}:{{.HostPort}}{{end}} {{end}}
privileged:   {{.HostConfig.Privileged}}
cap_add:      {{.HostConfig.CapAdd}}
devices:      {{range .HostConfig.Devices}}{{.PathOnHost}}:{{.PathInContainer}} {{end}}
sysctls:      {{.HostConfig.Sysctls}}
dns:          {{.HostConfig.Dns}}
cmd:          {{.Config.Cmd}}
mounts:
{{range .Mounts}}  {{.Type}} {{.Source}} -> {{.Destination}} ({{if .RW}}rw{{else}}ro{{end}})
{{end}}env:
{{range .Config.Env}}  {{.}}
{{end}}labels:
{{range $k,$v := .Config.Labels}}  {{$k}}={{$v}}
{{end}}' | REDACT
done

echo
echo "########## 6. ARRAY PATHS"
echo "--- top-level shares:"
ls -1 /mnt/user/ 2>/dev/null
echo "--- appdata:"
du -sh /mnt/user/appdata/* 2>/dev/null | sort -k2
echo "--- homepage config files (git will own these):"
find /mnt/user/appdata -maxdepth 3 -iname '*.yaml' -path '*homepage*' 2>/dev/null

echo
echo "########## 7. UNRAID DOCKER TEMPLATES"
for f in /boot/config/plugins/dockerMan/templates-user/*.xml; do
  [ -e "$f" ] || { echo "no templates found"; break; }
  echo "===== $f"
  REDACT < "$f"
done

echo
echo "########## END"
