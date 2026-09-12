#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:?Usage: ./deploy_pi.sh <user@pi-host>}"
BACKEND_PACKAGE="$ROOT_DIR/resources/debos/carnine-backend.deb"
FRONTEND_PACKAGE="$ROOT_DIR/resources/debos/carnine-frontend.deb"
REMOTE_DIR="/tmp/carnine-deploy-$$"

for package in "$BACKEND_PACKAGE" "$FRONTEND_PACKAGE"; do
  [[ -f "$package" ]] || {
    echo "ERROR: Debian package not found: $package" >&2
    echo "Run ./build_pi.sh first." >&2
    exit 1
  }
done

command -v ssh >/dev/null || { echo "ERROR: ssh is required" >&2; exit 1; }
command -v scp >/dev/null || { echo "ERROR: scp is required" >&2; exit 1; }

echo "Transferring Debian packages to $TARGET..."
ssh "$TARGET" mkdir -p "$REMOTE_DIR"
scp "$BACKEND_PACKAGE" "$FRONTEND_PACKAGE" "$TARGET:$REMOTE_DIR/"

echo "Stopping Carnine services, installing packages and restarting services..."
ssh "$TARGET" bash -s -- "$REMOTE_DIR" <<'REMOTE_SCRIPT'
set -euo pipefail
REMOTE_DIR="$1"

cleanup() {
  rm -rf "$REMOTE_DIR"
}
trap cleanup EXIT

restart_services() {
  sudo systemctl start carnine-backend.service carnine-frontend.service
}
trap restart_services ERR

sudo systemctl stop carnine-frontend.service carnine-backend.service
sudo dpkg -i "$REMOTE_DIR/carnine-backend.deb" "$REMOTE_DIR/carnine-frontend.deb"
sudo systemctl daemon-reload
restart_services
trap - ERR

sudo systemctl --no-pager --full status carnine-backend.service carnine-frontend.service
REMOTE_SCRIPT

echo "Deployment completed successfully."