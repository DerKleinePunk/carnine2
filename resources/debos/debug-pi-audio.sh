#!/usr/bin/env bash
set -euo pipefail

PI_HOST="${1:-carnine-pc.local}"
SSH_USER="${SSH_USER:-pi}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"

ssh -i "$SSH_KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
  -o PasswordAuthentication=no "$SSH_USER@$PI_HOST" 'bash -s' <<'REMOTE'
set -u

printf '%s\n' '--- identity and groups ---'
id
printf '\n%s\n' '--- carnine service ---'
systemctl status carnine-backend --no-pager -l || true
printf '\n%s\n' '--- installed backend ---'
dpkg-query -W -f='${Status} ${Version} ${Architecture}\n' carnine-backend 2>/dev/null || true
sha256sum /usr/bin/carnine-backend 2>/dev/null || true

printf '\n%s\n' '--- backend journal ---'
journalctl -u carnine-backend --since '3 hours ago' --no-pager -o short-precise || true

printf '\n%s\n' '--- audio and stream journal ---'
journalctl --since '3 hours ago' --no-pager | grep -Ei \
  'carnine|ffmpeg|aplay|alsa|pulse|broken pipe|underrun|overrun|xrun|audio|stream' || true

printf '\n%s\n' '--- Carnine file logs ---'
find /var/log/carnine -maxdepth 2 -type f -readable -print \
  -exec tail -n 80 {} \; 2>/dev/null || true

printf '\n%s\n' '--- audio processes ---'
ps -eo pid,ppid,stat,wchan:32,etime,cmd | \
  grep -E 'carnine|ffmpeg|paplay|aplay' | grep -v grep || true

printf '\n%s\n' '--- listening ports ---'
ss -ltn 2>/dev/null | grep -E '50051|LISTEN' || true

printf '\n%s\n' '--- ALSA devices ---'
aplay -l 2>&1 || true
aplay -L 2>&1 | head -n 80 || true

printf '\n%s\n' '--- PulseAudio status ---'
pactl info 2>&1 | head -n 40 || true
REMOTE
