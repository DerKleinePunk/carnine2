#!/bin/sh
# Stops the image build when the installed carnine-frontend is the MCP build.
#
# MCP (the local control socket tests drive the interface through) is for
# trade-fair and test devices only; build_pi.sh marks such a frontend with
# "+mcp" in its version. resources/debos/carnine-frontend.deb is whatever was
# built last, so an image could take it by mistake (2026-10-23: the jeep-pi
# package lay there). The check reads the dpkg status of the image's root file
# system, so nothing of the arm64 tree has to run on the build host.
#
# Usage: carnine-package-check.sh ROOTDIR [allow_mcp]
#   allow_mcp = "yes" lets an MCP frontend through (an image meant for a test
#   device, built with -t allow_mcp:yes); anything else refuses it.
# Tests: tests/carnine-package-check-test.sh

set -eu

rootdir="${1:?usage: carnine-package-check.sh ROOTDIR [allow_mcp]}"
allow_mcp="${2:-no}"
status="$rootdir/var/lib/dpkg/status"

[ -f "$status" ] || {
    echo "ERROR: no dpkg status in $rootdir" >&2
    exit 1
}

version=$(awk '
    /^Package: / { in_frontend = ($2 == "carnine-frontend") }
    /^$/ { in_frontend = 0 }
    in_frontend && /^Version: / { print $2; exit }
' "$status")

[ -n "$version" ] || {
    echo "ERROR: carnine-frontend is not installed in the image" >&2
    exit 1
}

case "$version" in
*+mcp*)
    if [ "$allow_mcp" = "yes" ]; then
        echo "carnine-frontend $version is the MCP build, allowed (allow_mcp:yes)"
    else
        echo "ERROR: carnine-frontend $version is the MCP build, not for an image." >&2
        echo "Build the frontend again without CARNINE_FRONTEND_MCP (./build_pi.sh)," >&2
        echo "or pass -t allow_mcp:yes for an image meant for a test device." >&2
        exit 1
    fi
    ;;
*)
    echo "carnine-frontend $version (without MCP)"
    ;;
esac
