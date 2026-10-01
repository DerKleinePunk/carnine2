#!/bin/sh
# Tests for carnine-rename.sh on a scratch tree; no root needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-rename.sh"
failures=0

# A device as carnine-hostname left it on first boot.
setup() {
    tree=$(mktemp -d)
    mkdir -p "$tree/etc" "$tree/state"
    printf 'carnine-pc-c3d4\n' > "$tree/etc/hostname"
    printf '127.0.0.1\tlocalhost\n127.0.1.1\tcarnine-pc-c3d4\n' > "$tree/etc/hosts"
    : > "$tree/set-hostname.log"
    # $1 belongs to the generated script, not to this one.
    # shellcheck disable=SC2016
    printf '#!/bin/sh\necho "$1" >> "%s/set-hostname.log"\n' "$tree" > "$tree/fake-hostname"
    chmod +x "$tree/fake-hostname"
}

run() {
    status=0
    CARNINE_ETC_DIR="$tree/etc" CARNINE_STATE_DIR="$tree/state" \
        CARNINE_SET_HOSTNAME="$tree/fake-hostname" CARNINE_SKIP_ROOT_CHECK=1 \
        sh "$SCRIPT" "$@" > "$tree/out.log" 2>&1 || status=$?
}

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        sed 's/^/    | /' "$tree/out.log"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

setup
run messe-auto-2
check "rename succeeds" "$status" "0"
check "hostname file" "$(cat "$tree/etc/hostname")" "messe-auto-2"
check "hosts line follows" "$(grep '^127.0.1.1' "$tree/etc/hosts")" "$(printf '127.0.1.1\tmesse-auto-2')"
check "localhost line stays" "$(grep -c '^127.0.0.1' "$tree/etc/hosts")" "1"
check "running hostname is set" "$(cat "$tree/set-hostname.log")" "messe-auto-2"
check "first-boot marker set" "$(test -e "$tree/state/hostname-set" && echo yes)" "yes"
check "old and new name shown" "$(grep -c 'carnine-pc-c3d4 → messe-auto-2' "$tree/out.log")" "1"
check "reboot hint" "$(grep -c 'sudo reboot' "$tree/out.log")" "1"
rm -rf "$tree"

# Without a 127.0.1.1 line one is added.
setup
printf '127.0.0.1\tlocalhost\n' > "$tree/etc/hosts"
run auto
check "hosts line added" "$(grep '^127.0.1.1' "$tree/etc/hosts")" "$(printf '127.0.1.1\tauto')"
rm -rf "$tree"

# Names that DHCP and mDNS cannot carry change nothing.
for bad in Messe messe_auto -messe messe- 'messe auto' '' \
    "$(printf 'a%.0s' $(seq 1 64))"; do
    setup
    run "$bad"
    check "refused: '$bad'" "$status" "1"
    check "refused '$bad': hostname kept" "$(cat "$tree/etc/hostname")" "carnine-pc-c3d4"
    check "refused '$bad': nothing set" "$(cat "$tree/set-hostname.log")" ""
    rm -rf "$tree"
done

# The longest name a label allows still goes.
setup
long=$(printf 'a%.0s' $(seq 1 63))
run "$long"
check "63 characters accepted" "$(cat "$tree/etc/hostname")" "$long"
rm -rf "$tree"

# Without a name or with two the usage is shown.
setup
run
check "no name refused" "$(grep -c 'Aufruf' "$tree/out.log")" "1"
run a b
check "two names refused" "$(grep -c 'Aufruf' "$tree/out.log")" "1"
rm -rf "$tree"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all carnine-rename tests passed"
