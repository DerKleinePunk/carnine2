#!/bin/sh
# Gives the device a new name: sudo carnine-rename <name>. Installed as
# /usr/local/sbin/carnine-rename. Sets /etc/hostname, the 127.0.1.1 line in
# /etc/hosts (without it sudo complains "unable to resolve host") and the
# running hostname in one step, and sets the marker of carnine-hostname (#62)
# so that the first-boot name never comes back. DHCP and mDNS (<name>.local)
# pick the name up after a reboot.
#
# The paths can be overridden so the tests can run it on a scratch tree.

set -eu

ETC_DIR=${CARNINE_ETC_DIR:-/etc}
STATE_DIR=${CARNINE_STATE_DIR:-/var/lib/carnine}
SET_HOSTNAME=${CARNINE_SET_HOSTNAME:-hostname}

die() {
    echo "FEHLER: $*" >&2
    exit 1
}

[ $# -eq 1 ] || die "Aufruf: sudo carnine-rename <name>, z. B. sudo carnine-rename messe-auto-2"
name=$1

if [ "$(id -u)" -ne 0 ] && [ -z "${CARNINE_SKIP_ROOT_CHECK:-}" ]; then
    die "bitte mit sudo aufrufen: sudo carnine-rename $name"
fi

# A hostname label (RFC 1123): 1 to 63 lowercase letters, digits and dashes,
# no dash at either end. Lowercase only, since DHCP and mDNS do not keep case.
if [ ${#name} -gt 63 ] || ! printf '%s' "$name" | grep -Eqx '[a-z0-9]([a-z0-9-]*[a-z0-9])?'; then
    die "'$name' geht nicht als Name: nur Kleinbuchstaben a-z, Ziffern und -, höchstens 63 Zeichen, nicht mit - anfangen oder enden"
fi

old=$(cat "$ETC_DIR/hostname" 2>/dev/null || true)
printf '%s\n' "$name" > "$ETC_DIR/hostname"
if grep -q "^127\.0\.1\.1[[:space:]]" "$ETC_DIR/hosts" 2>/dev/null; then
    sed -i "s/^127\.0\.1\.1[[:space:]].*/127.0.1.1\t$name/" "$ETC_DIR/hosts"
else
    printf '127.0.1.1\t%s\n' "$name" >> "$ETC_DIR/hosts"
fi
"$SET_HOSTNAME" "$name"
mkdir -p "$STATE_DIR"
: > "$STATE_DIR/hostname-set"

echo "Name geändert: ${old:-?} → $name"
echo "Im Netz (DHCP, $name.local) gilt er nach einem Neustart: sudo reboot"
