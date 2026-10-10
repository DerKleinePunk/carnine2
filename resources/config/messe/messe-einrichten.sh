#!/usr/bin/env bash
# Switches the trade fair mode (Messe-Modus) on or off on a Carnine device.
#
#   messe-einrichten.sh USER@HOST an  [FIXED-ADDRESS]
#   messe-einrichten.sh USER@HOST aus
#
# an:  copies the tour to /var/lib/carnine/maps/messe-tour.nmea and
#      90-messe.toml to /etc/carnine/config.d/, then restarts the backend and
#      the frontend. With FIXED-ADDRESS (192.168.77.2 for carnine-pc) the
#      device also keeps that address beside DHCP, on systemd-networkd
#      (image devices); on NetworkManager it says so and leaves the network.
# aus: removes 90-messe.toml and restarts; tour file and fixed address stay.
#
# Silent: the backend starts the music only with resume_mode auto-play, at
# the volume it had. Runs from the laptop or WSL, like deploy_pi.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USAGE="Usage: messe-einrichten.sh USER@HOST an [FIXED-ADDRESS] | aus"
TARGET="${1:?$USAGE}"
ACTION="${2:?$USAGE}"
ADDRESS="${3:-}"
SSH=(ssh -o ConnectTimeout=10 "$TARGET")

restart() {
  "${SSH[@]}" 'sudo systemctl restart carnine-backend && sudo systemctl restart carnine-frontend'
}

case "$ACTION" in
  an)
    if [[ -n "$ADDRESS" && ! "$ADDRESS" =~ ^192\.168\.77\.[0-9]{1,3}$ ]]; then
      echo "messe-einrichten: fixed address must be 192.168.77.x, got $ADDRESS" >&2
      exit 1
    fi
    scp -q "$HERE/messe-tour.nmea" "$HERE/90-messe.toml" "$TARGET:/tmp/"
    "${SSH[@]}" 'sudo install -m 0644 -o carnine -g carnine /tmp/messe-tour.nmea /var/lib/carnine/maps/messe-tour.nmea &&
      sudo install -m 0640 -o root -g carnine /tmp/90-messe.toml /etc/carnine/config.d/90-messe.toml &&
      rm -f /tmp/messe-tour.nmea /tmp/90-messe.toml'
    if [[ -n "$ADDRESS" ]]; then
      if "${SSH[@]}" 'systemctl is-active --quiet systemd-networkd'; then
        sed "s/@ADDRESS@/$ADDRESS/" "$HERE/50-messe.network.conf" |
          "${SSH[@]}" 'sudo install -d -m 0755 /etc/systemd/network/wired.network.d &&
            sudo tee /etc/systemd/network/wired.network.d/50-messe.conf >/dev/null &&
            sudo networkctl reload'
        echo "messe-einrichten: fixed address $ADDRESS beside DHCP"
      else
        echo "messe-einrichten: no systemd-networkd here (NetworkManager?); fixed address not set." >&2
        echo "  nmcli con modify \"Wired connection 1\" +ipv4.addresses $ADDRESS/24 && nmcli con up \"Wired connection 1\"" >&2
      fi
    fi
    restart
    echo "messe-einrichten: trade fair mode on ($TARGET)"
    ;;
  aus)
    "${SSH[@]}" 'sudo rm -f /etc/carnine/config.d/90-messe.toml'
    restart
    echo "messe-einrichten: trade fair mode off ($TARGET)"
    ;;
  *)
    echo "$USAGE" >&2
    exit 1
    ;;
esac
