#!/bin/sh
# Notes whether the login user still has the image's well-known default
# password, so that /etc/profile.d/carnine-password.sh can warn on every
# login, on the console and over SSH. A login shell cannot read /etc/shadow
# itself, so this part runs as root: at boot and whenever /etc/shadow changes
# (carnine-password-check.path), which makes the warning go away right after
# `passwd`. Like Raspberry Pi OS did with /run/sshwarn up to Bullseye.
#
# The paths can be overridden so the tests can run it on a scratch tree.

set -eu

SHADOW=${CARNINE_SHADOW:-/etc/shadow}
MARKER=${CARNINE_PASSWORD_MARKER:-/run/carnine-default-password}
LOGIN_USER=${CARNINE_LOGIN_USER:-pi}
DEFAULT_PASSWORD=${CARNINE_DEFAULT_PASSWORD:-raspberry}

hash=$(awk -F: -v user="$LOGIN_USER" '$1 == user { print $2 }' "$SHADOW" 2>/dev/null || true)

# perl-base is part of every Debian system and uses the system crypt(3), so
# it checks yescrypt as well as the older SHA-512 hashes. A locked or empty
# entry (!, *, "") does not start with $ and is never the default password.
if [ -n "$hash" ] && HASH="$hash" PASSWORD="$DEFAULT_PASSWORD" perl -e '
    my $hash = $ENV{HASH};
    exit 1 unless $hash =~ /^\$/;
    my $try = crypt($ENV{PASSWORD}, $hash);
    exit(defined $try && $try eq $hash ? 0 : 1);'; then
    mkdir -p "$(dirname "$MARKER")"
    printf '%s\n' "$LOGIN_USER" > "$MARKER"
    echo "user $LOGIN_USER still has the default password"
else
    rm -f "$MARKER"
fi
