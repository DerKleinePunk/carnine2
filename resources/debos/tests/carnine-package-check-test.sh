#!/bin/sh
# Tests for carnine-package-check.sh on a scratch dpkg status; no root needed.

set -eu

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/carnine-package-check.sh"
failures=0

check() {
    if [ "$2" != "$3" ]; then
        echo "FAIL: $1: expected '$3', got '$2'"
        failures=$((failures + 1))
    else
        echo "ok: $1"
    fi
}

# A root file system whose dpkg status holds the given carnine-frontend
# version, between two other packages (empty: not installed).
tree_with() {
    tree=$(mktemp -d)
    mkdir -p "$tree/var/lib/dpkg"
    {
        printf 'Package: carnine-backend\nStatus: install ok installed\nVersion: 0.19.1+mcp-not-the-frontend\n\n'
        if [ -n "$1" ]; then
            printf 'Package: carnine-frontend\nStatus: install ok installed\nArchitecture: arm64\nVersion: %s\nDescription: x\n\n' "$1"
        fi
        printf 'Package: zlib1g\nStatus: install ok installed\nVersion: 1:1.3.dfsg+really1.3.1-1+b1\n'
    } > "$tree/var/lib/dpkg/status"
    echo "$tree"
}

result() {
    if sh "$SCRIPT" "$@" > /dev/null 2>&1; then echo passes; else echo stops; fi
}

customer='0.19.1+git20261023080519.5ce03e57a8b5'
mcp='0.19.1+git20261023081253.5ce03e57a8b5+mcp'

check "the customer frontend passes" "$(result "$(tree_with "$customer")")" passes
check "the MCP frontend stops the build" "$(result "$(tree_with "$mcp")")" stops
check "the MCP frontend passes with allow_mcp:yes" "$(result "$(tree_with "$mcp")" yes)" passes
check "only yes allows it" "$(result "$(tree_with "$mcp")" true)" stops
check "another package's +mcp does not count" "$(result "$(tree_with "$customer")")" passes
check "a missing frontend stops the build" "$(result "$(tree_with "")")" stops
check "a missing dpkg status stops the build" "$(result "$(mktemp -d)")" stops

tree=$(tree_with "$mcp")
message=$(sh "$SCRIPT" "$tree" 2>&1 || true)
case "$message" in
*"$mcp is the MCP build"*CARNINE_FRONTEND_MCP*) check "the error names version and remedy" yes yes ;;
*) check "the error names version and remedy" "$message" "version + remedy" ;;
esac

if [ "$failures" -ne 0 ]; then
    echo "$failures test(s) failed"
    exit 1
fi
echo "all tests passed"
