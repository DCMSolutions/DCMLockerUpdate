#!/usr/bin/env bash
# Retrofits a Gen-1 Raspberry Pi locker onto the Gen-2 STD, keeping the OS it already runs
# (Raspbian 11, .NET 5 in /opt/dotnet, Gen-1 in /home/pi/DCMLocker).
#
# The retrofit is one-way. Gen-1's app and state are copied, not moved; its service unit is kept as
# dcmlocker.service.gen1 and its kiosk launcher as kiosk-launcher.sh.gen1. A run that fails before the unit
# swap removes what it created and restarts Gen-1.
#
# Usage:  sudo bash retrofit-pi.sh [release|latest]
#   PKG_URL=<url>   payload source; defaults to the GitLab generic package for the channel
#   NO_REBOOT=1     restart the service instead of rebooting; the kiosk switches at the next reboot
set -euo pipefail

CANAL="${1:-release}"
APP_DIR="/home/DCMLockerLastUbuntu"   # updateUbuntu.sh swaps exactly this path on every update
STATE_DIR="/home"                      # Gen-2 reads LoackerConfig/LoackerMap from the parent of APP_DIR
GEN1_STATE="/home/pi"                  # ...which for Gen-1 in /home/pi/DCMLocker is /home/pi
GEN1_BASE='/home/pi/DCMLocker\Base'    # PathBase = working directory + a literal "\Base"
GEN2_BASE="${APP_DIR}\\Base"
UNIT="/etc/systemd/system/dcmlocker.service"
KIOSK_LAUNCHER="/home/pi/kiosk-launcher.sh"   # started by the LXDE autostart entry /etc/xdg/autostart/display.desktop
PKG_URL="${PKG_URL:-https://git.dcmservidor.ar/api/v4/projects/2/packages/generic/dcmlocker/${CANAL}/dcmlocker.tar.gz}"

log(){ printf '\n==> %s\n' "$*"; }
info(){ printf '    %s\n' "$*"; }
warn(){ printf '    AVISO: %s\n' "$*"; }
die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }
fail(){ printf 'ERROR: %s\n' "$*" >&2; return 1; }
have_systemd(){ [ -d /run/systemd/system ]; }

# Everything this run creates is removed again if a step fails before the unit swap,
# so a failed run leaves Gen-1 as it was and can be retried.
CREATED=()
SWAPPED=0
on_err(){
  local rc=$?
  printf 'ERROR: línea %s (exit %s)\n' "$1" "$rc" >&2
  if [ "$SWAPPED" = 0 ]; then
    for p in "${CREATED[@]}"; do rm -rf -- "$p"; done
    if have_systemd; then systemctl start dcmlocker || true; fi
    printf 'Cambios deshechos; Gen-1 sigue como estaba.\n' >&2
  fi
  exit "$rc"
}
trap 'on_err $LINENO' ERR

# --- 0) preconditions -------------------------------------------------------
log "0) Precondiciones"
[ "$(id -u)" = 0 ] || die "correr como root (sudo)"
case "$CANAL" in release|latest) ;; *) die "canal inválido '$CANAL': usar release o latest" ;; esac
ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
  armhf|arm64) info "userland $ARCH" ;;
  *) die "userland $ARCH: este script es para lockers Raspberry Pi" ;;
esac
if ! /opt/dotnet/dotnet --list-runtimes 2>/dev/null | grep -q '^Microsoft\.AspNetCore\.App 5\.0\.'; then
  die "no hay ASP.NET Core 5.0 en /opt/dotnet"
fi
for f in LoackerConfig.config LoackerMap.map; do
  [ -s "$GEN1_STATE/$f" ] || die "falta el estado Gen-1 $GEN1_STATE/$f"
  if [ -e "$STATE_DIR/$f" ]; then die "$STATE_DIR/$f ya existe: ¿retrofit ya aplicado?"; fi
done
if [ -e "$APP_DIR" ]; then die "$APP_DIR ya existe: ¿retrofit ya aplicado?"; fi
if [ -e "${UNIT}.gen1" ]; then die "${UNIT}.gen1 ya existe: ¿retrofit ya aplicado?"; fi
[ -f "$KIOSK_LAUNCHER" ] || die "falta el lanzador del kiosk $KIOSK_LAUNCHER"
if [ -e "${KIOSK_LAUNCHER}.gen1" ]; then die "${KIOSK_LAUNCHER}.gen1 ya existe: ¿retrofit ya aplicado?"; fi
LOCKER_ID="$(grep -oE '"LockerID":"[^"]*"' "$GEN1_STATE/LoackerConfig.config" | cut -d'"' -f4)"
[ -n "$LOCKER_ID" ] || die "LoackerConfig.config no tiene LockerID"
info "LockerID $LOCKER_ID"

# --- 1) payload -------------------------------------------------------------
log "1) Firmware Gen-2, canal $CANAL"
CREATED+=("${APP_DIR}.new")
mkdir -p "${APP_DIR}.new"
curl -fsSL "$PKG_URL" | tar -xz -C "${APP_DIR}.new"
[ -f "${APP_DIR}.new/DCMLocker.Server.dll" ] || fail "el paquete no trae DCMLocker.Server.dll"
CREATED+=("$APP_DIR")
mv "${APP_DIR}.new" "$APP_DIR"
info "instalado en $APP_DIR (VERSION $(cat "$APP_DIR/VERSION" 2>/dev/null || echo '?'))"

# --- 2) locker state --------------------------------------------------------
log "2) Estado del locker"
# Gen-1 rewrites the map when boxes change; stop it so the copy is consistent.
if have_systemd; then systemctl stop dcmlocker; info "Gen-1 detenido"; fi
for f in LoackerConfig.config LoackerMap.map; do
  CREATED+=("$STATE_DIR/$f")
  cp -p "$GEN1_STATE/$f" "$STATE_DIR/$f"
done
info "LoackerConfig.config y LoackerMap.map copiados a $STATE_DIR"
if [ -d "$GEN1_BASE" ]; then
  CREATED+=("$GEN2_BASE")
  cp -a "$GEN1_BASE" "$GEN2_BASE"
  info "Base copiada: contraseña de admin y usuarios del locker"
else
  warn "no existe $GEN1_BASE: Gen-2 va a crear la contraseña de admin por defecto"
fi

# --- 3) runtime config ------------------------------------------------------
log "3) Configuración de runtime (/home/config.json)"
# Only Modo is seeded; Gen-2 fills every other setting with Config2's defaults on first run, as on the
# all-in-ones. That keeps DireccionUpdater at "GitHub", the updater source lockers can fetch anonymously,
# and the kiosk PINs at 6641 (admin) and 3942 (superadmin), the codes Gen-1 kiosks already use.
if [ -e /home/config.json ]; then
  info "ya existe, no se modifica"
else
  CREATED+=("/home/config.json")
  printf '{"Modo":"tokens"}\n' > /home/config.json
  info "Modo=tokens; el resto con los valores por defecto del firmware"
fi

# --- 4) service unit --------------------------------------------------------
log "4) Servicio dcmlocker"
if [ -f "$UNIT" ]; then
  CREATED+=("${UNIT}.gen1")
  cp -p "$UNIT" "${UNIT}.gen1"
  info "unidad Gen-1 guardada en ${UNIT}.gen1"
fi
SWAPPED=1
cat > "$UNIT" <<EOF
[Unit]
Description=dcmlocker
After=network.target

[Service]
WorkingDirectory=${APP_DIR}
ExecStart=/opt/dotnet/dotnet DCMLocker.Server.dll
Restart=always
SyslogIdentifier=dcmlocker
User=root
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
EOF
info "unidad apunta a $APP_DIR"

# --- 5) kiosk ---------------------------------------------------------------
log "5) Kiosk"
# Chromium launches as on the all-in-ones (instalador-ubuntu.sh): incognito on a throwaway profile, so no
# page zoom, HTTP cache or service worker carries over from Gen-1 or from a previous firmware build. Gen-1's
# persistent profile stays on disk, unused. --no-sandbox is left out: the all-in-ones need it for their
# kiosk user, and Gen-1's launcher runs Chromium as pi without it.
cp -p "$KIOSK_LAUNCHER" "${KIOSK_LAUNCHER}.gen1"
info "lanzador Gen-1 guardado en ${KIOSK_LAUNCHER}.gen1"
cat > "$KIOSK_LAUNCHER" <<'EOF'
#!/usr/bin/env bash
chromium-browser \
  --disable-infobars \
  --disable-pinch \
  --disable-features=OverscrollHistoryNavigation,TouchpadOverscrollHistoryNavigation \
  --kiosk \
  --incognito \
  --password-store=basic \
  --user-data-dir=/tmp/kiosk-profile \
  --force-device-scale-factor=1 \
  "file:///home/pi/reloader.html" 2> "$HOME/kiosk-error.log"
EOF
info "kiosk en incógnito sobre /tmp/kiosk-profile desde el próximo arranque"

# --- 6) activation ----------------------------------------------------------
log "6) Activación"
if have_systemd; then
  systemctl daemon-reload
  if [ "${NO_REBOOT:-0}" = 1 ]; then
    systemctl restart dcmlocker
    info "dcmlocker corriendo Gen-2; el kiosk cambia en el próximo arranque"
  else
    info "reiniciando"
    sync
    reboot
  fi
else
  info "sin systemd: arrancar según $UNIT"
fi
printf '\nRetrofit aplicado a %s.\n' "$LOCKER_ID"
