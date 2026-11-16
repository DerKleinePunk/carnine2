#!/bin/sh
# Tests for apt-cache-arg.sh with stand-ins for getent and curl.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/apt-cache-arg.sh"
tree=$(mktemp -d)
trap 'rm -rf "$tree"' EXIT
failures=0

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

# fakes <getent answer> <curl exit code>; curl logs the address it was given.
fakes() {
    printf '#!/bin/sh\n[ -n "%s" ] && echo "%s"\nexit 0\n' "$1" "$1" > "$tree/getent"
    # shellcheck disable=SC2016 # the $ belongs to the fake script
    printf '#!/bin/sh\nfor a; do last=$a; done\necho "$last" >> "%s/curl.log"\nexit %s\n' "$tree" "$2" > "$tree/curl"
    chmod +x "$tree/getent" "$tree/curl"
    : > "$tree/curl.log"
}

# run [CARNINE_APT_CACHE]: stdout of the script.
run() {
    CARNINE_APT_CACHE=${1:-} CARNINE_GETENT="$tree/getent" CARNINE_CURL="$tree/curl" \
        sh "$SCRIPT" 2> "$tree/err.log"
}

fakes "192.168.2.57    aptcache.example" 0
check "no cache set: nothing" "$(run)" ""
check "no cache set: no lookup" "$(cat "$tree/curl.log")" ""
check "cache answers: debos argument with the address" "$(run http://aptcache:3142)" \
    "-e http_proxy:http://192.168.2.57:3142"
check "cache answers: asked by address" "$(cat "$tree/curl.log")" "http://192.168.2.57:3142/"
check "no port: 80" "$(run http://aptcache)" "-e http_proxy:http://192.168.2.57:80"
check "a path after the port is ignored" "$(run http://aptcache:3142/acng-report.html)" \
    "-e http_proxy:http://192.168.2.57:3142"

fakes "192.168.2.57    aptcache.example" 28
check "cache does not answer: nothing" "$(run http://aptcache:3142)" ""
check "cache does not answer: says so" "$(grep -c 'does not answer' "$tree/err.log")" "1"

fakes "" 0
check "name unknown: nothing" "$(run http://aptcache:3142)" ""
check "name unknown: says so" "$(grep -c 'not found' "$tree/err.log")" "1"
check "name unknown: no request" "$(cat "$tree/curl.log")" ""

check "https address: nothing" "$(run https://aptcache:3142)" ""

status=0
CARNINE_APT_CACHE=http://aptcache:3142 CARNINE_GETENT="$tree/getent" CARNINE_CURL=false \
    sh "$SCRIPT" > /dev/null 2>&1 || status=$?
check "never fails the build" "$status" "0"

if [ "$failures" -ne 0 ]; then
    echo "$failures failure(s)"
    exit 1
fi
echo "all apt-cache-arg tests passed"
