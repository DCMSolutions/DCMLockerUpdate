#!/usr/bin/env bash
#
# instalador-ubuntu.sh
# --------------------
# Provisions a fresh AlmaLinux 9 machine into an STD locker (Gen 2, Ubuntu line):
# .NET runtime, the DCMLocker app, its systemd service, the GNOME kiosk session,
# x11vnc and Tailscale.
#
# Run as root on the locker, either from a checkout:
#
#     sudo TS_AUTHKEY=tskey-auth-kpKVDKu6gT11CNTRL-qvrwRG2Ew296bpJ7WMmm29grFPi9Ri4Q3 \
#          bash instalador-ubuntu.sh
#
# or straight off the repo:
#
#     curl -fsSL https://raw.githubusercontent.com/DCMSolutions/DCMLockerUpdate/main/instalador-ubuntu.sh | sudo TS_AUTHKEY=tskey-auth-kpKVDKu6gT11CNTRL-qvrwRG2Ew296bpJ7WMmm29grFPi9Ri4Q3 bash
#
# In the piped form the variables go AFTER sudo. Putting them in front of curl
# sets them for curl, and sudo resets the environment anyway, so the script sees
# nothing: the install still succeeds but the locker never joins the tailnet.
#
# Re-running is safe: every step either overwrites its own output or checks for
# what it creates, so a partial install can be finished by running it again.
#
# Env knobs (all optional except TS_AUTHKEY, which the script asks about):
#   CANAL=release|latest   Update channel to install from. Default "release" —
#                          the pinned build production lockers run. Use "latest"
#                          only for a test locker.
#   TS_AUTHKEY=tskey-...   Tailscale auth key — the fleet key is in the examples
#                          above. This repo is publicly mirrored, so treat that
#                          key as compromised and rotate it. Without the variable
#                          the script installs and enables tailscaled but does
#                          not join the tailnet.
#   LOCKER_NAME=<name>     Tailnet node name; becomes "locker-<name>". Defaults
#                          to this machine's hostname so a reinstall reuses its
#                          node instead of leaving a duplicate behind. Set it:
#                          a stock install that was never named reports
#                          "localhost", and the fallback name it gets instead
#                          ("locker-sin-nombre-<id>") means nothing to anyone
#                          reading the Tailscale console.
#   KIOSK_PASS=<pass>      Password for the local 'kiosk' user. Default AlmaLinux.
#   VNC_PASS=<pass>        Password for the VNC server on 5900. Default AlmaLinux.
#   WAN_CON / LAN_CON      NetworkManager connection names. Defaults match the
#                          stock locker image; the script fails loudly if they
#                          are not found rather than leaving the LAN unconfigured.
#   LAN_IP=<cidr>          Static LAN address. Default 192.168.2.3/24 — the subnet
#                          the lock controller (192.168.2.178) lives on.
#   SKIP_NETWORK=1         Leave NetworkManager alone (machine already wired up).
#   NO_REBOOT=1            Finish without rebooting.
#
set -Eeuo pipefail

# --- configuration ---------------------------------------------------------
CANAL="${CANAL:-release}"
GITLAB_URL="https://git.dcmservidor.ar"
PROJECT_ID="2"                       # dcm/dcmlockerclienteubuntu
APP_DIR="/home/DCMLockerLastUbuntu"

DOTNET_VERSION="5.0.408"
DOTNET_TGZ="dotnet-sdk-${DOTNET_VERSION}-linux-x64.tar.gz"
DOTNET_URL="https://builds.dotnet.microsoft.com/dotnet/Sdk/${DOTNET_VERSION}/${DOTNET_TGZ}"

WAN_CON="${WAN_CON:-Conexión cableada 1}"
LAN_CON="${LAN_CON:-enp1s0}"
WAN_IFACE="${WAN_IFACE:-enp0s20u1}"
LAN_IP="${LAN_IP:-192.168.2.3/24}"

KIOSK_PASS="${KIOSK_PASS:-AlmaLinux}"
VNC_PASS="${VNC_PASS:-AlmaLinux}"
TS_AUTHKEY="${TS_AUTHKEY:-}"

# Tailnet node name. A stock AlmaLinux install that was never given a hostname
# reports "localhost", which would have every locker in the fleet claiming the
# same node — so fall back to a stable per-machine id and say so, rather than
# handing out a name that collides.
_default_locker_name() {
  local h; h="$(hostname -s 2>/dev/null || true)"
  case "$h" in
    ""|localhost|localhost.localdomain)
      # machine-id can be absent or empty (it is written at first boot), so an
      # exit-status check is not enough — test the value.
      local id; id="$(cut -c1-8 /etc/machine-id 2>/dev/null || true)"
      printf 'sin-nombre-%s' "${id:-desconocido}" ;;
    # A host already named "locker-algo" would otherwise become locker-locker-algo.
    locker-*) printf '%s' "${h#locker-}" ;;
    *) printf '%s' "$h" ;;
  esac
}
LOCKER_NAME_EXPLICIT=1
[ -n "${LOCKER_NAME:-}" ] || LOCKER_NAME_EXPLICIT=0
LOCKER_NAME="${LOCKER_NAME:-$(_default_locker_name)}"

SKIP_NETWORK="${SKIP_NETWORK:-0}"
NO_REBOOT="${NO_REBOOT:-0}"

log()  { printf '\n=== %s ===\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    AVISO: %s\n' "$*" >&2; }
die()  { printf '\nERROR: %s\n' "$*" >&2; exit 1; }

trap 'rc=$?; printf "\nInstalación INTERRUMPIDA: comando=%q | línea=%s | exit=%s\nEl sistema quedó a medio configurar: corregí el problema y volvé a ejecutar el script.\n" "$BASH_COMMAND" "$LINENO" "$rc" >&2' ERR

# --- 0) preconditions ------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "hay que ejecutarlo como root (sudo bash instalador-ubuntu.sh)."
[ "$CANAL" = "release" ] || [ "$CANAL" = "latest" ] || die "CANAL inválido: '$CANAL'. Use 'release' o 'latest'."
grep -qi 'almalinux' /etc/os-release || warn "esto no parece un AlmaLinux; el script asume dnf/firewalld/GDM."
command -v curl >/dev/null 2>&1 || die "falta curl (lo usa todo el script para descargar)."

echo "Instalador STD — canal '${CANAL}', locker '${LOCKER_NAME}'. Inicio: $(date -Is)"
[ "$CANAL" = "latest" ] && warn "canal 'latest': build sin pinear, solo para lockers de prueba."

# --- 1) base packages ------------------------------------------------------
# Downloads go through curl, which AlmaLinux ships as curl-minimal. Asking dnf
# for the full `curl` package conflicts with it, and wget is not installed at
# all, so neither belongs in this list.
# libicu/krb5-libs/zlib/compat-openssl11 are .NET 5's native dependencies. A
# GNOME install drags them in anyway, but the app FailFasts on boot without ICU
# ("Couldn't find a valid ICU package"), so the installer declares them itself
# instead of inheriting them by luck.
log "1) Paquetes base"
dnf update -y
dnf install -y git tar compat-openssl11 libicu krb5-libs zlib \
               glibc-langpack-es systemd-resolved firewalld

# --- 2) network ------------------------------------------------------------
# The LAN side carries the lock controller, so a silently-unconfigured LAN means
# a locker that boots, serves its UI, and cannot open a single box. Failing here
# is better than discovering it on site.
log "2) Red (WAN preferida, LAN estática hacia la placa de cerraduras)"
if [ "$SKIP_NETWORK" = "1" ]; then
  info "SKIP_NETWORK=1 — no se toca NetworkManager."
elif ! command -v nmcli >/dev/null 2>&1; then
  warn "nmcli no está instalado; se omite la configuración de red."
else
  nmcli -t -f NAME,DEVICE connection show | sed 's/^/    perfil: /'

  if nmcli -t -f NAME connection show | grep -qxF "$WAN_CON"; then
    nmcli con mod "$WAN_CON" connection.interface-name "$WAN_IFACE"
    nmcli con mod "$WAN_CON" ipv4.route-metric 100 ipv6.route-metric 100
    nmcli con up  "$WAN_CON" || warn "no se pudo levantar la WAN '$WAN_CON'."
  else
    warn "no existe el perfil WAN '$WAN_CON'. Ajustá WAN_CON=... y volvé a correr el script."
  fi

  if nmcli -t -f NAME connection show | grep -qxF "$LAN_CON"; then
    nmcli con mod "$LAN_CON" connection.interface-name "$LAN_CON"
    nmcli con mod "$LAN_CON" ipv4.route-metric 300 ipv6.route-metric 300
    nmcli con mod "$LAN_CON" ipv4.method manual ipv4.addresses "$LAN_IP" \
                             ipv4.gateway "" ipv4.dns "" ipv4.never-default yes
    nmcli connection reload
    nmcli con down "$LAN_CON" || true
    nmcli con up   "$LAN_CON" || warn "no se pudo levantar la LAN '$LAN_CON'."

    if ip -4 addr show | grep -q "${LAN_IP%%/*}"; then
      info "LAN en ${LAN_IP} — OK."
    else
      warn "la LAN no quedó en ${LAN_IP}. El locker no va a poder abrir cajas hasta arreglarlo."
    fi
  else
    warn "no existe el perfil LAN '$LAN_CON'. Ajustá LAN_CON=... y volvé a correr el script."
  fi
fi

# --- 3) .NET ---------------------------------------------------------------
log "3) .NET ${DOTNET_VERSION} en /opt/dotnet"
if [ -x /opt/dotnet/dotnet ]; then
  info "ya instalado: $(/opt/dotnet/dotnet --version)"
else
  mkdir -p /opt/dotnet
  curl -fL --retry 3 -o "/tmp/${DOTNET_TGZ}" "$DOTNET_URL"
  tar -zxf "/tmp/${DOTNET_TGZ}" -C /opt/dotnet
  rm -f "/tmp/${DOTNET_TGZ}"
fi
cat >/etc/profile.d/dotnet.sh <<'EOF'
export DOTNET_ROOT=/opt/dotnet
export PATH=$DOTNET_ROOT:$PATH
EOF
# shellcheck source=/dev/null
source /etc/profile.d/dotnet.sh
/opt/dotnet/dotnet --list-runtimes | grep -q 'Microsoft.AspNetCore.App 5' \
  || die ".NET quedó instalado pero sin el runtime ASP.NET Core 5; el servicio no va a arrancar."
info "runtimes: $(/opt/dotnet/dotnet --list-runtimes | tr '\n' ' ')"

# --- 4) firewall -----------------------------------------------------------
log "4) Firewall (5020 admin, 5022 kiosk, 5900 VNC)"
systemctl enable --now firewalld
for port in 5020 5022 5900; do
  firewall-cmd --add-port="${port}/tcp" --permanent >/dev/null
done
firewall-cmd --reload >/dev/null
info "puertos abiertos: $(firewall-cmd --list-ports)"

# --- 5) application --------------------------------------------------------
# Same source and channel layout as updateUbuntu.sh, so a fresh install and a
# self-update always land on the same build. The old GitHub artifact repo
# (DCMSolutions/DCMLockerLastUbuntu) is gone — anonymous clones of it fail.
log "5) Aplicación DCMLocker (canal ${CANAL})"
PKG_URL="${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/packages/generic/dcmlocker/${CANAL}/dcmlocker.tar.gz"
rm -rf "${APP_DIR}.new"
mkdir -p "${APP_DIR}.new"
curl -sfL "$PKG_URL" | tar -xz -C "${APP_DIR}.new" \
  || die "no se pudo descargar/extraer el paquete desde ${PKG_URL}"
[ -f "${APP_DIR}.new/DCMLocker.Server.dll" ] \
  || die "el paquete descargado no contiene DCMLocker.Server.dll."

if [ -d "$APP_DIR" ]; then
  rm -rf "${APP_DIR}.old"
  mv "$APP_DIR" "${APP_DIR}.old"
  info "instalación previa movida a ${APP_DIR}.old"
fi
mv "${APP_DIR}.new" "$APP_DIR"
info "instalado en ${APP_DIR}"

# The app owns its own state: Config2Store creates /home/config.json with
# defaults on first read, and LogController creates /home/eventos on first write.
# Nothing to seed here.

# --- 6) systemd service ----------------------------------------------------
log "6) Servicio dcmlocker"
cat >/etc/systemd/system/dcmlocker.service <<EOF
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
systemctl daemon-reload
systemctl enable dcmlocker
systemctl restart dcmlocker

# --- 7) kiosk packages -----------------------------------------------------
# The whole graphical stack the steps below configure is named here: GDM is what
# autologin is written for, Xorg is what WaylandEnable=false falls back to, and
# xset (xorg-x11-server-utils) is what the launcher calls to stop the screen
# blanking. A Workstation image already carries them; a Server/minimal one does
# not, and without them the locker installs cleanly and boots to a black screen.
log "7) Entorno kiosk (Chromium + GNOME Kiosk + Xorg)"
dnf install -y epel-release
dnf install -y chromium gnome-kiosk gnome-kiosk-script-session x11vnc \
               gdm xorg-x11-server-Xorg xorg-x11-server-utils xorg-x11-xinit

# --- 8) kiosk user ---------------------------------------------------------
log "8) Usuario kiosk"
id -u kiosk >/dev/null 2>&1 || useradd -m -s /bin/bash kiosk
echo "kiosk:${KIOSK_PASS}" | chpasswd
[ "$KIOSK_PASS" = "AlmaLinux" ] && warn "usuario kiosk con la contraseña por defecto. Pasá KIOSK_PASS=... para cambiarla."
install -d -o kiosk -g kiosk /home/kiosk/.local/bin /home/kiosk/.config /home/kiosk/.local/share/xorg

# --- 9) autologin ----------------------------------------------------------
log "9) GDM autologin (Xorg, sin Wayland)"
mkdir -p /etc/gdm
cat >/etc/gdm/custom.conf <<'EOF'
[daemon]
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=kiosk

[security]

[xdmcp]

[chooser]

[debug]
EOF

mkdir -p /var/lib/AccountsService/users
cat >/var/lib/AccountsService/users/kiosk <<'EOF'
[User]
Language=es_AR.utf8
Session=gnome-kiosk-script
SystemAccount=false
EOF

# --- 10) kiosk session -----------------------------------------------------
log "10) Sesión de kiosk"
cat >/usr/share/xsessions/gnome-kiosk-script.desktop <<'EOF'
[Desktop Entry]
Name=Kiosk Script Session
Comment=This session logs you into the session started by ~/.local/bin/gnome-kiosk-script
Exec=gnome-session --session gnome-kiosk-script
TryExec=gnome-session
Type=Application
DesktopNames=GNOME-Kiosk;GNOME;
X-GDM-SessionRegisters=true
EOF

cat >/usr/share/applications/org.gnome.Kiosk.Script.desktop <<'EOF'
[Desktop Entry]
Name=Kiosk Script
Type=Application
Exec=/home/kiosk/.local/bin/gnome-kiosk-script
X-GNOME-HiddenUnderSystemd=true
EOF

# The launcher is written ONCE, here. updateUbuntu.sh only swaps the app
# tarball, so a Chromium flag added below reaches new installs only; deployed
# lockers need the corresponding one-shot patch script.
cat >/home/kiosk/.local/bin/gnome-kiosk-script <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

export PATH="$HOME/.local/bin:$PATH"

# Fallback: si no existe chromium-browser, crear alias local a /usr/bin/chromium
if ! command -v chromium-browser >/dev/null 2>&1 && command -v chromium >/dev/null 2>&1; then
  ln -sf "$(command -v chromium)" "$HOME/.local/bin/chromium-browser"
fi

pkill -9 chromium || true
pkill -9 chromium-browser || true

# Evitar apagado de pantalla/ahorro de energía
xset s off
xset -dpms
xset s noblank

# Ajustes de sesión GNOME
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver idle-activation-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power idle-dim false
gsettings set org.gnome.desktop.a11y.applications screen-magnifier-enabled false

sleep 1

# Lanzar Chromium en modo kiosk hacia un reloader local.
# Flags (uno por linea, en el mismo orden que abajo):
#   --disable-infobars      Oculta las barras de aviso de Chromium (ej. "Chrome esta
#                           siendo controlado por software automatizado").
#   --disable-pinch         Desactiva el zoom por gesto de pellizco (pinch) en la pantalla tactil.
#   --disable-features=OverscrollHistoryNavigation,TouchpadOverscrollHistoryNavigation
#                           Desactiva el gesto "deslizar para volver/avanzar" (swipe = atras/adelante)
#                           en tactil y touchpad.
#   --kiosk                 Modo kiosko a pantalla completa: sin barra de direcciones, pestañas ni controles.
#   --no-sandbox            Desactiva el sandbox de Chromium (necesario para correr como el usuario kiosk).
#   --incognito             Sesion de incognito: sin historial ni datos persistentes entre arranques.
#   --user-data-dir=/tmp/kiosk-profile   Perfil efimero en /tmp; se descarta en cada reinicio del locker.
#   --force-device-scale-factor=1        Fija la escala de la interfaz en 1 (sin escalado por DPI).
# Argumento final: file:///home/kiosk/reloader.html (pagina que redirige al backend local);
# "2>" redirige los errores de Chromium a ~/kiosk-error.log.
chromium-browser \
  --disable-infobars \
  --disable-pinch \
  --disable-features=OverscrollHistoryNavigation,TouchpadOverscrollHistoryNavigation \
  --kiosk \
  --no-sandbox \
  --incognito \
  --user-data-dir=/tmp/kiosk-profile \
  --force-device-scale-factor=1 \
  "file:///home/kiosk/reloader.html" 2> "$HOME/kiosk-error.log"
EOF
chmod +x /home/kiosk/.local/bin/gnome-kiosk-script
chown kiosk:kiosk /home/kiosk/.local/bin/gnome-kiosk-script

cat >/home/kiosk/reloader.html <<'EOF'
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="refresh" content="1;url=http://localhost:5022" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cargando Aplicación...</title>
  <style>
    body { background:#fff; color:#000; font-family:Arial, sans-serif;
           display:flex; flex-direction:column; align-items:center;
           justify-content:center; height:100vh; margin:0; }
    h1   { font-size:2.0rem; margin-bottom:10px; }
    p    { font-size:1.1rem; opacity:0.8; }
    .spinner { margin-top:30px; width:40px; height:40px; border:4px solid #ccc;
               border-top:4px solid #00bfff; border-radius:50%; animation:spin 1s linear infinite; }
    @keyframes spin { to { transform: rotate(360deg); } }
  </style>
</head>
<body>
  <h1>Cargando Aplicación...</h1>
  <p>Serás redirigido automáticamente</p>
  <div class="spinner"></div>
</body>
</html>
EOF
chown kiosk:kiosk /home/kiosk/reloader.html

# --- 11) vnc ---------------------------------------------------------------
log "11) x11vnc en :0 (puerto 5900)"
su - kiosk -c "mkdir -p ~/.vnc && x11vnc -storepasswd '${VNC_PASS}' ~/.vnc/passwd"
[ "$VNC_PASS" = "AlmaLinux" ] && warn "VNC con la contraseña por defecto. Pasá VNC_PASS=... para cambiarla."

cat >/etc/systemd/system/x11vnc.service <<'EOF'
[Unit]
Description=x11vnc server on display :0
After=graphical.target
Requires=graphical.target

[Service]
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -rfbauth /home/kiosk/.vnc/passwd -forever -loop -noxdamage -repeat -rfbport 5900 -shared
Restart=always
User=kiosk
Environment=DISPLAY=:0

[Install]
WantedBy=graphical.target
EOF
systemctl daemon-reload
systemctl enable x11vnc

# --- 12) graphical boot ----------------------------------------------------
log "12) Arranque gráfico"
systemctl enable gdm.service
systemctl set-default graphical.target

# --- 13) tailscale ---------------------------------------------------------
log "13) Tailscale"
# AlmaLinux 9 ships systemd-resolved DISABLED (90-default.preset), so it has to
# be enabled, not just started: the symlink below points at a file that only
# exists while resolved runs, and this script reboots at the end. Enable first,
# then link, or the locker comes back up with a dangling resolv.conf and no DNS.
systemctl enable --now systemd-resolved
if ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf 2>/dev/null; then
  info "/etc/resolv.conf apunta a systemd-resolved."
else
  warn "no se pudo reemplazar /etc/resolv.conf (lo administra otro componente). Revisá el DNS a mano."
fi

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh
  bash /tmp/tailscale-install.sh
  rm -f /tmp/tailscale-install.sh
fi
systemctl enable --now tailscaled

if [ -n "$TS_AUTHKEY" ]; then
  [ "$LOCKER_NAME_EXPLICIT" = "1" ] \
    || warn "no pasaste LOCKER_NAME: el nodo se va a llamar 'locker-${LOCKER_NAME}'. Renombralo en la consola de Tailscale o volvé a correr con LOCKER_NAME=<nombre>."
  # Hostname derives from LOCKER_NAME (not a timestamp) so reinstalling a locker
  # reuses its tailnet node instead of leaving a duplicate behind.
  tailscale up --authkey="$TS_AUTHKEY" --ssh --hostname="locker-${LOCKER_NAME}" \
    || warn "'tailscale up' falló (¿auth key vencida o revocada?). El resto de la instalación sigue; corré el comando a mano cuando tengas una key válida."
else
  warn "sin TS_AUTHKEY: el locker NO se unió a la tailnet."
  info "Para unirlo: sudo tailscale up --authkey=<key> --ssh --hostname=locker-${LOCKER_NAME}"
fi

systemctl restart systemd-resolved
systemctl restart NetworkManager || true

# --- 14) verification ------------------------------------------------------
log "14) Verificación"
ok=0; bad=0
verify() { if eval "$2" >/dev/null 2>&1; then info "OK   $1"; ok=$((ok+1)); else warn "FALLA $1"; bad=$((bad+1)); fi; }

verify "aplicación en ${APP_DIR}"         "test -f ${APP_DIR}/DCMLocker.Server.dll"
verify "runtime .NET"                     "test -x /opt/dotnet/dotnet"
verify "servicio dcmlocker habilitado"    "systemctl is-enabled --quiet dcmlocker"
verify "servicio dcmlocker activo"        "systemctl is-active --quiet dcmlocker"
verify "lanzador del kiosk"               "test -x /home/kiosk/.local/bin/gnome-kiosk-script"
verify "reloader.html"                    "test -f /home/kiosk/reloader.html"
verify "autologin de kiosk"               "grep -q '^AutomaticLogin=kiosk' /etc/gdm/custom.conf"
verify "arranque gráfico"                 "test \"\$(systemctl get-default)\" = graphical.target"
verify "x11vnc habilitado"                "systemctl is-enabled --quiet x11vnc"
verify "systemd-resolved habilitado"      "systemctl is-enabled --quiet systemd-resolved"
verify "DNS resuelve"                     "getent hosts git.dcmservidor.ar"

# Give the app a moment to bind before checking the port it must serve.
for _ in $(seq 1 15); do
  curl -sfo /dev/null --max-time 3 http://localhost:5022/ && break
  sleep 2
done
verify "kiosk responde en :5022"          "curl -sfo /dev/null --max-time 5 http://localhost:5022/"
verify "admin responde en :5020"          "curl -sfo /dev/null --max-time 5 http://localhost:5020/"

echo
if [ "$bad" -gt 0 ]; then
  journalctl -u dcmlocker -n 20 --no-pager || true
  die "${bad} verificación(es) fallaron (${ok} OK). NO reiniciar hasta resolverlas."
fi
echo "Instalación OK — ${ok} verificaciones pasaron. Fin: $(date -Is)"

# --- 15) reboot ------------------------------------------------------------
if [ "$NO_REBOOT" = "1" ]; then
  info "NO_REBOOT=1 — reiniciá a mano para entrar en modo kiosk."
  exit 0
fi
echo "Reiniciando para entrar en modo kiosk..."
sync
reboot
