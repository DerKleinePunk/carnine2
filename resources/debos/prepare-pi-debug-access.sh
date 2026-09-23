#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-carnine-pc.local}"

ssh -t "$PI_HOST" 'bash -s' <<'REMOTE'
set -euo pipefail

sudo apt-get install -y acl
sudo usermod -aG adm pi

echo 'pi ALL=(ALL) NOPASSWD: ALL' | sudo tee /etc/sudoers.d/90-pi-nopasswd >/dev/null
sudo chmod 0440 /etc/sudoers.d/90-pi-nopasswd
sudo visudo -cf /etc/sudoers.d/90-pi-nopasswd

if [[ -d /var/log/carnine ]]; then
  sudo setfacl -R -m u:pi:rX /var/log/carnine
  sudo setfacl -m d:u:pi:rX /var/log/carnine
fi

printf '%s\n' 'Debug-Zugriff vorbereitet.'
printf '%s\n' 'Bitte die SSH-Verbindung beenden und neu anmelden, damit die Gruppe adm aktiv wird.'
REMOTE
