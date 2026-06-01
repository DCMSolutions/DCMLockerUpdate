#!/usr/bin/env bash
set -euo pipefail

exec >>/home/run.ans 2>&1
trap 'rc=$?; printf "[%s] ERROR: comando=%q | linea=%s | exit=%s\n" \
  "$(date -Is)" "$BASH_COMMAND" "$LINENO" "$rc" >> /home/error.ans; exit "$rc"' ERR

echo "=== Inicio: $(date -Is) ==="

GITLAB_URL="https://git.dcmservidor.ar"
PROJECT_ID="2"

# Update channel to pull. Defaults to "release" — the pinned, known-good build
# production lockers run. Pass "latest" as the first arg for the bleeding-edge
# build (test lockers only). The firmware passes this via `bash -s -- <canal>`;
# an arg-less invocation (old firmware / manual run) resolves "release".
CHANNEL="${1:-release}"
echo "Canal de actualización: ${CHANNEL}"

cd /home

find /home -maxdepth 1 -type f -name 'eventos-*' -print -delete

rm -rf /home/DCMLockerLastUbuntu.new
mkdir -p /home/DCMLockerLastUbuntu.new
curl -sfL \
  "$GITLAB_URL/api/v4/projects/$PROJECT_ID/packages/generic/dcmlocker/${CHANNEL}/dcmlocker.tar.gz" \
  | tar -xz -C /home/DCMLockerLastUbuntu.new

rm -rf /home/DCMLockerLastUbuntu.old
mv /home/DCMLockerLastUbuntu /home/DCMLockerLastUbuntu.old
mv /home/DCMLockerLastUbuntu.new /home/DCMLockerLastUbuntu

sync
reboot
