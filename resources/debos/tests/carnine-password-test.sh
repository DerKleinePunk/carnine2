#!/bin/sh
# Tests for carnine-password-check.sh and the login warning
# carnine-password.sh on a scratch tree; no root needed.
# The crypt salts below hold literal $ signs.
# shellcheck disable=SC2016

set -eu

DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK="$DIR/carnine-password-check.sh"
PROFILE="$DIR/carnine-password.sh"
failures=0

# A shadow file whose pi entry carries $1 as its hash.
setup() {
    tree=$(mktemp -d)
    printf 'root:*:20000:0:99999:7:::\npi:%s:20000:0:99999:7:::\n' "$1" > "$tree/shadow"
}

hash_of() {
    PASSWORD="$1" SALT="$2" perl -e 'print crypt($ENV{PASSWORD}, $ENV{SALT})'
}

run() {
    CARNINE_SHADOW="$tree/shadow" CARNINE_PASSWORD_MARKER="$tree/run/carnine-default-password" \
        sh "$CHECK" > /dev/null
}

marker() {
    if [ -e "$tree/run/carnine-default-password" ]; then echo yes; else echo no; fi
}

# The login warning as an interactive login shell would print it.
warning() {
    CARNINE_PASSWORD_MARKER="$tree/run/carnine-default-password" sh -i -c ". '$PROFILE'" 2>/dev/null
}

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

# yescrypt, as chpasswd writes it on Debian trixie (the image).
setup "$(hash_of raspberry '$y$j9T$F5Jx5fExrKuPp53xLKQ..1$')"
run
check "yescrypt default password is found" "$(marker)" "yes"
check "marker names the user" "$(cat "$tree/run/carnine-default-password")" "pi"
check "login warning is shown" "$(warning | grep -c 'passwd')" "2"
check "non-interactive shell stays quiet" \
    "$(CARNINE_PASSWORD_MARKER="$tree/run/carnine-default-password" sh -c ". '$PROFILE'")" ""

# After passwd: the next check removes the marker, the warning is gone.
sed -i "s|^pi:[^:]*:|pi:$(hash_of 'eigenes Passwort' '$y$j9T$abcdefghijklmnopqrstu.$'):|" "$tree/shadow"
run
check "changed password removes the marker" "$(marker)" "no"
check "no warning after the change" "$(warning)" ""
rm -rf "$tree"

# SHA-512, as older images or a hand-made entry may have.
setup "$(hash_of raspberry '$6$carnine$')"
run
check "sha512 default password is found" "$(marker)" "yes"
rm -rf "$tree"

setup "$(hash_of geheim '$6$carnine$')"
run
check "other sha512 password" "$(marker)" "no"
rm -rf "$tree"

# Locked and empty entries never count as the default password.
for locked in '!' '*' '!$y$j9T$F5Jx5fExrKuPp53xLKQ..1$x' ''; do
    setup "$locked"
    run
    check "locked or empty entry '$locked'" "$(marker)" "no"
    rm -rf "$tree"
done

# No pi user at all.
tree=$(mktemp -d)
printf 'root:*:20000:0:99999:7:::\n' > "$tree/shadow"
run
check "no pi user" "$(marker)" "no"
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all carnine-password tests passed"
