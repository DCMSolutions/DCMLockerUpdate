#!/usr/bin/env bash
set -euo pipefail

exec >>/home/run.ans 2>&1
trap 'rc=$?; printf "[%s] ERROR: comando=%q | linea=%s | exit=%s\n" \
  "$(date -Is)" "$BASH_COMMAND" "$LINENO" "$rc" >> /home/error.ans; exit "$rc"' ERR

echo "=== Inicio: $(date -Is) ==="

GITLAB_URL="https://git.dcmservidor.ar"
PROJECT_ID="2"

cd /home

find /home -maxdepth 1 -type f -name 'eventos-*' -print -delete

rm -rf /home/DCMLockerLastUbuntu.new
mkdir -p /home/DCMLockerLastUbuntu.new
curl -sfL \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/packages/generic/dcmlocker/latest/dcmlocker.tar.gz" \
  | tar -xz -C /home/DCMLockerLastUbuntu.new

rm -rf /home/DCMLockerLastUbuntu.old
mv /home/DCMLockerLastUbuntu /home/DCMLockerLastUbuntu.old
mv /home/DCMLockerLastUbuntu.new /home/DCMLockerLastUbuntu

sync
reboot
