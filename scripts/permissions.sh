#!/usr/bin/env bash
# Ownership and mode across the shared trees. Tickets 09, 19, 20.
#
# The box had been chmod -R 777'd as a stopgap: containers run UMASK=022, so
# they create dirs 755 owned nobody:users, and rb (uid 1001, gid 100) could
# read media but not *move* it -- rename and delete need write on the parent
# directory, not the file. 777 fixed the symptom and opened the tree.
#
# The cure is 09's: everything 99:100, UMASK=002, so gid 100 is a collaborator
# rather than a spectator. nobody(99), share(1000) and rseaforthb(1001) all
# have primary gid 100 already, which is why group-write is sufficient and
# no chown of the media tree is needed -- only its modes are wrong.
#
# Samba is not implicated: its effective create/directory masks are 0777, so
# it strips nothing. Do not "fix" smb-extra.conf.

set -euo pipefail

tower="${TOWER_SSH:-root@tower}"

media="/mnt/user/Media"
appdata="/mnt/user/appdata"
komodo="$appdata/komodo"

# Service appdata that diverges from 99:100 today. Ticket 20's table.
divergent=(plexmediaserver qbittorrent gluetun transcode)

# Never touched by a blanket pass:
#   komodo/postgres, komodo/ferretdb  -- database state owned by uid 999/1000;
#                                        loosening it makes postgres refuse to
#                                        start, and it is not shared with anyone
#   komodo/keys, komodo/age.key       -- 0600 root, the root of the secret story
#   komodo/backups                    -- Komodo's own dumps of the above
#   caddy/data                        -- holds the *.rbrb.in private key
#   portainer                         -- already 0700/0600, and leaves with 25
prune_expr=(
    -path "$komodo/postgres" -prune -o
    -path "$komodo/ferretdb" -prune -o
    -path "$komodo/keys" -prune -o
    -path "$komodo/backups" -prune -o
    -path "$appdata/caddy/data" -prune -o
    -path "$appdata/portainer" -prune -o
)

remote() {
    # shellcheck disable=SC2029  # commands are built here, not on the box
    ssh "$tower" "$1"
}

audit() {
    echo "== world-writable =="
    remote "
        printf '%-34s %s\n' 'media dirs (o+w):' \
            \"\$(find $media -type d -perm -o=w 2>/dev/null | wc -l)\"
        printf '%-34s %s\n' 'media files (o+w):' \
            \"\$(find $media -type f -perm -o=w 2>/dev/null | wc -l)\"
        printf '%-34s %s\n' 'appdata dirs (o+w):' \
            \"\$(find $appdata ${prune_expr[*]} -type d -perm -o=w -print 2>/dev/null | wc -l)\"
        printf '%-34s %s\n' 'appdata files (o+w):' \
            \"\$(find $appdata ${prune_expr[*]} -type f -perm -o=w -print 2>/dev/null | wc -l)\"
    "

    echo
    echo "== media not group-writable (this is what blocks rb) =="
    remote "
        printf '%-34s %s\n' 'dirs without g+w:' \
            \"\$(find $media -type d ! -perm -g=w 2>/dev/null | wc -l)\"
        find $media -type d ! -perm -g=w -printf '  %M %u:%g %p\n' 2>/dev/null | head -5
    "

    echo
    echo "== appdata not owned 99:100 =="
    remote "
        for d in ${divergent[*]}; do
            [ -e $appdata/\$d ] || continue
            printf '  %-20s %s\n' \"\$d\" \
                \"\$(stat -c '%U:%G  %a' $appdata/\$d) (\$(find $appdata/\$d ! -uid 99 2>/dev/null | wc -l) paths off-uid)\"
        done
    "

    echo
    echo "== decrypted secrets =="
    remote "find $komodo -name secrets.env -printf '  %M %u:%g %p\n' 2>/dev/null"

    echo
    echo "== container UMASK (022 is the bug; 002 is the fix) =="
    remote "
        for n in \$(docker ps --format '{{.Names}}'); do
            env=\$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' \$n 2>/dev/null)
            u=\$(echo \"\$env\" | grep -E '^UMASK=' | cut -d= -f2)
            p=\$(echo \"\$env\" | grep -E '^PUID=' | cut -d= -f2)
            g=\$(echo \"\$env\" | grep -E '^PGID=' | cut -d= -f2)
            [ -n \"\$u\$p\$g\" ] && printf '  %-24s PUID=%-5s PGID=%-5s UMASK=%s\n' \
                \"\$n\" \"\${p:--}\" \"\${g:--}\" \"\${u:--}\"
        done
    " || true
}

# The only real rollback for a recursive chmod is a record of what was there.
snapshot() {
    local dest="$komodo/backups/permissions-\$(date +%Y-%m-%d_%H-%M-%S).manifest.gz"
    printf "  find %s %s -printf '%%m %%U:%%G %%p\\\\n' | gzip > %s\n" \
        "$media" "$appdata" "$dest"
}

plan() {
    cat <<EOF
1. snapshot every mode and owner under $media and $appdata (the rollback):
$(snapshot)

2. $media -- modes only, no chown. Every writer is already gid 100:
     find $media -type d -exec chmod 775 {} +
     find $media -type f -exec chmod 664 {} +

3. $appdata -- close world-write only, and *relatively*. An absolute 664 here
   would strip the execute bit from komodo/bin/sops and from the codecs plex
   downloads into its own appdata and then runs:
     find $appdata <prunes> -type d -exec chmod g+w,o-w {} +
     find $appdata <prunes> -type f -exec chmod o-w {} +

4. the services that diverge from 99:100:
     chown -R 99:100 ${divergent[*]/#/$appdata/}

5. the two directories that are 777 at the top:
     chmod 755 $komodo
     chmod 775 $appdata

6. re-tighten what must not be group-readable:
     chmod 600 \$(find $komodo -name secrets.env)
     chmod 600 $komodo/age.key

7. remove $appdata/scratch -- ticket 01's leftovers, 777 with executable
   scripts in it. Its contents are already in the repo under
   .scratch/unraid-gitops/assets/.
EOF
}

apply_all() {
    local apply=0
    case "${1:-}" in
    --apply) apply=1 ;;
    "") ;;
    *)
        echo "usage: permissions.sh apply [--apply]" >&2
        exit 1
        ;;
    esac

    plan

    if ((!apply)); then
        cat <<'EOF'

dry run -- nothing was changed. re-run with:  just permissions --apply

before applying, know that steps 2-4 do not stick on their own: a container
still running UMASK=022 recreates 755 directories the next time it imports.
The UMASK flip is a separate change to each service's definition.
EOF
        return
    fi

    echo
    echo "== applying =="
    remote "
        set -e
        dest=$komodo/backups/permissions-\$(date +%Y-%m-%d_%H-%M-%S).manifest.gz
        find $media $appdata -printf '%m %U:%G %p\n' 2>/dev/null | gzip > \"\$dest\"
        echo \"snapshot: \$dest (\$(stat -c %s \"\$dest\") bytes)\"

        find $media -type d -exec chmod 775 {} +
        find $media -type f -exec chmod 664 {} +
        echo 'media normalised'

        find $appdata ${prune_expr[*]} -type d -exec chmod g+w,o-w {} + 2>/dev/null || true
        find $appdata ${prune_expr[*]} -type f -exec chmod o-w {} + 2>/dev/null || true
        echo 'appdata normalised'

        for d in ${divergent[*]}; do
            [ -e $appdata/\$d ] && chown -R 99:100 $appdata/\$d
        done
        echo 'divergent services chowned to 99:100'

        chmod 755 $komodo
        chmod 775 $appdata

        find $komodo -name secrets.env -exec chmod 600 {} +
        chmod 600 $komodo/age.key
        echo 'secrets re-tightened'

        rm -rf $appdata/scratch
        echo 'scratch removed'
    "

    echo
    echo "== after =="
    audit
}

case "${1:-}" in
audit) audit ;;
apply)
    shift
    apply_all "$@"
    ;;
*)
    echo "usage: permissions.sh audit | apply [--apply]" >&2
    exit 1
    ;;
esac
