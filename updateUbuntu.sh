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

# Chromium flags the kiosk launcher must carry. The launcher is written once, by
# instalador-ubuntu.sh (all-in-ones) or retrofit-pi.sh (Raspberry Pi), and
# nothing rewrites it afterwards, so a flag added after a locker shipped reaches
# the fleet only from here: each flag below is inserted into whichever launcher
# exists when it is missing. A launcher that is absent or not in the expected
# shape is left as it is — the firmware update goes through either way.
#   --no-first-run   The launcher runs Chromium on a throwaway profile, so every
#                    boot is a first run; without this flag Chromium can open its
#                    first-run page (a "terms of service" stub) over the kiosk.
KIOSK_FLAGS=(--no-first-run)
KIOSK_LAUNCHERS=(/home/kiosk/.local/bin/gnome-kiosk-script /home/pi/kiosk-launcher.sh)

patch_kiosk_launcher() {
  local launcher="$1" flag tmp backup
  [ -f "$launcher" ] || return 0
  if ! grep -qE '^[[:space:]]*chromium-browser[[:space:]]*\\$' "$launcher"; then
    echo "Launcher ${launcher}: sin línea 'chromium-browser \\' reconocible; no se toca"
    return 0
  fi
  for flag in "${KIOSK_FLAGS[@]}"; do
    grep -qF -- "$flag" "$launcher" && continue
    tmp="$(mktemp)"
    # awk, not sed: GNU sed's a/i drops the trailing ' \' continuation on some
    # versions, which would cut the chromium-browser command short. The flag goes
    # right after the `chromium-browser \` line, at its indentation plus two
    # spaces, the way the installers lay the flags out.
    awk -v flag="$flag" '
      { print }
      /^[[:space:]]*chromium-browser[[:space:]]*\\$/ {
        match($0, /^[[:space:]]*/)
        print substr($0, 1, RLENGTH) "  " flag " \\"
      }
    ' "$launcher" > "$tmp"
    if ! grep -qF -- "$flag" "$tmp" || ! bash -n "$tmp"; then
      rm -f "$tmp"
      echo "Launcher ${launcher}: no se pudo insertar ${flag}; queda como estaba"
      continue
    fi
    backup="${launcher}.bak.$(date +%Y%m%d%H%M%S)"
    cp -a "$launcher" "$backup"
    cat "$tmp" > "$launcher"   # overwrite in place: keeps the launcher's owner and mode
    rm -f "$tmp"
    echo "Launcher ${launcher}: agregado ${flag} (backup en ${backup})"
  done
}

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

# The `|| echo` keeps an unexpected failure inside the patch from tripping the
# ERR trap: the firmware is already swapped, and the reboot below must happen.
for launcher in "${KIOSK_LAUNCHERS[@]}"; do
  patch_kiosk_launcher "$launcher" || echo "Launcher ${launcher}: parche omitido por un error inesperado"
done

sync
reboot
