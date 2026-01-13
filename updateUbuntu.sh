#!/usr/bin/env bash
set -euo pipefail

exec >>/home/run.ans 2>&1
trap 'rc=$?; printf "[%s] ERROR: comando=%q | linea=%s | exit=%s\n" \
  "$(date -Is)" "$BASH_COMMAND" "$LINENO" "$rc" >> /home/error.ans; exit "$rc"' ERR

echo "=== Inicio: $(date -Is) ==="

cd /home

find /home -maxdepth 1 -type f -name 'eventos-*' -print -delete

rm -rf /home/DCMLockerLastUbuntu.new
git clone --depth 1 https://github.com/DCMSolutions/DCMLockerLastUbuntu.git /home/DCMLockerLastUbuntu.new

rm -rf /home/DCMLockerLastUbuntu.old
mv /home/DCMLockerLastUbuntu /home/DCMLockerLastUbuntu.old
mv /home/DCMLockerLastUbuntu.new /home/DCMLockerLastUbuntu

sync
reboot
