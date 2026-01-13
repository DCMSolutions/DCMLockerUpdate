#!/usr/bin/env bash
set -euo pipefail

ERROR_LOG="/home/error.ans"
RUN_LOG="/home/run.ans"

exec >>"$RUN_LOG" 2>&1

trap 'rc=$?; printf "[%s] ERROR: comando=%q | linea=%s | exit=%s\n" \
  "$(date -Is)" "$BASH_COMMAND" "$LINENO" "$rc" >> "$ERROR_LOG"; exit "$rc"' ERR

echo "=== Inicio: $(date -Is) ==="
echo "pwd inicial: $(pwd)"

# Muy importante: salir de cualquier ruta que pueda ser borrada
cd / || exit 1
echo "pwd forzado: $(pwd)"

find /home -maxdepth 1 -type f -name 'eventos-*' -print -delete

rm -rf /home/DCMLockerLastUbuntu

git clone --depth 1 https://github.com/DCMSolutions/DCMLockerLastUbuntu.git /home/DCMLockerLastUbuntu

sleep 1
sync
reboot
