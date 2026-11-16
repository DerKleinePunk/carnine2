#!/bin/sh
# Prints the debos argument that sends the image build's apt downloads through
# an apt cache (apt-cacher-ng), or nothing. Used in the podman call of
# resources/debos/README.md:
#
#   CARNINE_APT_CACHE=http://aptcache:3142   (e.g. in ~/.bashrc of the build machine)
#   podman run ... godebos/debos $(sh debos/apt-cache-arg.sh) --memory=4G ...
#
# Without CARNINE_APT_CACHE, or when the cache does not answer within 3 s,
# the build fetches from the mirrors as before - outside the home network it
# simply runs without. The proxy is only an environment variable of the
# build; nothing of it lands in the image. The host name is resolved here,
# since the build VM of debos may not know local names.
#
# Measured 2026-11-16 (hdmi image): with pipelining off 1119 s, with the cache
# as well 1064 s.

set -u

URL=${CARNINE_APT_CACHE:-}
GETENT=${CARNINE_GETENT:-getent}
CURL=${CARNINE_CURL:-curl}

[ -n "$URL" ] || exit 0

case "$URL" in
    http://*) ;;
    *) echo "apt cache: $URL is not an http:// address, building without" >&2; exit 0 ;;
esac
hostport=${URL#http://}
hostport=${hostport%%/*}
host=${hostport%:*}
port=80
[ "$host" = "$hostport" ] || port=${hostport##*:}

ip=$("$GETENT" hosts "$host" 2>/dev/null | awk '{ print $1; exit }')
if [ -z "$ip" ]; then
    echo "apt cache: $host not found, building without" >&2
    exit 0
fi
# Any HTTP answer will do: apt-cacher-ng answers / with its usage page.
if "$CURL" -s -m 3 -o /dev/null "http://$ip:$port/"; then
    echo "apt cache: $host ($ip:$port)" >&2
    printf -- '-e http_proxy:http://%s:%s\n' "$ip" "$port"
else
    echo "apt cache: $host ($ip:$port) does not answer, building without" >&2
fi
exit 0
