#!/bin/bash
# unraid-ops — ticket 01, part 2.
#
# Redoes section 5 (the template blew up on .HostConfig.Sysctls), plus the
# Portainer stack definition and image digests. Paste the whole output back.

# Redacts KEY=value pairs, bare 32+ hex runs, and unraid <Config Mask="true">
# element text — the last of which part 1 missed.
REDACT() {
  sed -E \
    -e 's/([A-Za-z0-9_]*(PASS|PASSWD|PASSWORD|KEY|TOKEN|SECRET|CRED|PRIVATE|WIREGUARD|APIKEY|AUTH|USER)[A-Za-z0-9_]*)=[^[:space:]"'"'"']*/\1=<<REDACTED — needs a secret>>/g' \
    -e 's/(Mask="true"[^>]*>)[^<]*/\1<<REDACTED-MASKED — needs a secret>>/g' \
    -e 's/(<Config Name="[^"]*([Pp]ass|[Kk]ey|[Tt]oken|[Ss]ecret|[Uu]ser)[^"]*"[^>]*>)[^<]*/\1<<REDACTED — needs a secret>>/g' \
    -e 's/[A-Fa-f0-9]{32,}/<<REDACTED-HEX>>/g'
}

echo "########## 5. CONTAINER DETAIL (retry)"
for c in $(docker ps -a --format '{{.Names}}'); do
  echo "===== $c"
  docker inspect "$c" --format \
'image:        {{.Config.Image}}
restart:      {{.HostConfig.RestartPolicy.Name}}
network_mode: {{.HostConfig.NetworkMode}}
networks:     {{range $k,$v := .NetworkSettings.Networks}}{{$k}}(ip={{$v.IPAddress}}) {{end}}
ports:        {{range $p,$b := .HostConfig.PortBindings}}{{$p}}->{{range $b}}{{.HostIp}}:{{.HostPort}}{{end}} {{end}}
exposed:      {{range $p,$v := .Config.ExposedPorts}}{{$p}} {{end}}
privileged:   {{.HostConfig.Privileged}}
cap_add:      {{.HostConfig.CapAdd}}
devices:      {{range .HostConfig.Devices}}{{.PathOnHost}}:{{.PathInContainer}} {{end}}
cmd:          {{.Config.Cmd}}
mounts:
{{range .Mounts}}  {{.Type}} {{.Source}} -> {{.Destination}} ({{if .RW}}rw{{else}}ro{{end}})
{{end}}env:
{{range .Config.Env}}  {{.}}
{{end}}labels:
{{range $k,$v := .Config.Labels}}  {{$k}}={{$v}}
{{end}}' 2>&1 | REDACT
done

echo
echo "########## 5b. WHO IS ROUTED THROUGH WHOM"
# network_mode of container:<id> is the VPN-sidecar pattern; resolve the id to a name.
for c in $(docker ps -a --format '{{.Names}}'); do
  nm=$(docker inspect "$c" --format '{{.HostConfig.NetworkMode}}')
  case "$nm" in
    container:*) echo "$c -> $(docker inspect "${nm#container:}" --format '{{.Name}}' 2>/dev/null)" ;;
    *) echo "$c -> $nm" ;;
  esac
done

echo
echo "########## 8. PORTAINER STACK (qbittorrent + gluetun)"
echo "--- stack dirs:"
ls -R /mnt/user/appdata/portainer/compose/ 2>/dev/null || echo "no compose dir under portainer appdata"
echo "--- stack files:"
find /mnt/user/appdata/portainer/compose/ -maxdepth 3 -type f 2>/dev/null | while read -r f; do
  echo "===== $f"
  REDACT < "$f"
done

echo
echo "########## 9. IMAGE DIGESTS (not redacted — digests are not secrets)"
docker images --digests --format 'table {{.Repository}}\t{{.Tag}}\t{{.Digest}}\t{{.CreatedSince}}' | grep -v '<none>'

echo
echo "########## 10. MISSING TEMPLATES"
echo "--- everything under dockerMan:"
find /boot/config/plugins/dockerMan/ -name '*.xml' 2>/dev/null
echo "--- any plex template anywhere on /boot:"
find /boot -iname '*plex*.xml' 2>/dev/null

echo
echo "########## 11. MEDIA LAYOUT"
ls -1 /mnt/user/Media/ 2>/dev/null

echo
echo "########## END PART 2"
