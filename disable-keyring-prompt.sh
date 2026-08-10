#!/usr/bin/env bash
#
# disable-keyring-prompt.sh
# -------------------------
# One-shot retrofit for already-deployed Ubuntu/AlmaLinux STD lockers.
#
# Adds the Chromium flag that stops GNOME Keyring from asking for a keyring
# password over the kiosk on every boot ("Elija la contraseña para el depósito
# de claves — Una aplicación quiere crear un depósito de claves nuevo llamado
# «Default Keyring»").
#
# Cause: with no --password-store flag Chromium auto-detects GNOME and asks the
# Secret Service where to keep saved passwords. The kiosk user arrives via GDM
# autologin, so no keyring was ever unlocked by a login password and none
# exists — hence the offer to create one. Cancelling creates nothing, so it
# returns on the next boot, which is why neither Cancelar, Continuar nor typing
# a password makes it stop. --password-store=basic keeps Chromium out of the
# Secret Service entirely. Safe here because the launcher already runs
# --incognito against an ephemeral --user-data-dir: there are no credentials to
# store either way.
#
# New installs already get this from instalador-ubuntu.sh. This script exists
# because the launcher is written ONCE at install time and the normal app update
# (updateUbuntu.sh) only swaps the Blazor tarball — it never rewrites the
# launcher. So lockers installed before the flag was added need this patch.
#
# Run as root on the locker (reboots on success so Chromium relaunches):
#     sudo bash disable-keyring-prompt.sh
#   or remotely:
#     wget -qO- https://raw.githubusercontent.com/DCMSolutions/DCMLockerUpdate/main/disable-keyring-prompt.sh | sudo bash
#
# Env:
#   NO_REBOOT=1   patch only, don't reboot (restart the kiosk session by hand).
#
set -euo pipefail

LAUNCHER="/home/kiosk/.local/bin/gnome-kiosk-script"
# Keep this string in sync with the awk insert below.
FLAG="--password-store=basic"
NO_REBOOT="${NO_REBOOT:-0}"

log() { printf '[disable-keyring-prompt] %s\n' "$*"; }
die() { printf '[disable-keyring-prompt] ERROR: %s\n' "$*" >&2; exit 1; }

# --- preconditions ---------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "must run as root (sudo bash disable-keyring-prompt.sh)."
[ -f "$LAUNCHER" ]   || die "launcher not found at $LAUNCHER — is this an Ubuntu-line STD locker?"

# --- idempotency / conflict guard -----------------------------------------
# (FLAG starts with '--', so every grep that takes it as a pattern needs '--'.)
if grep -qF -- "$FLAG" "$LAUNCHER"; then
  log "Flag already present — nothing to do."
  exit 0
fi
if grep -q -- '--password-store=' "$LAUNCHER"; then
  die "a different --password-store= value already exists; merge by hand (Chromium honors only one)."
fi
grep -q '^chromium-browser' "$LAUNCHER" || die "no 'chromium-browser' launch line; launcher format unexpected, aborting."

# --- patch -----------------------------------------------------------------
# awk (not sed) because GNU sed's a/i backslash handling silently drops the
# trailing ' \' continuation on some versions, which would terminate the
# chromium-browser command early. awk string '\\' is exactly one backslash, so
# the inserted line keeps its line-continuation. Insert it as the first
# argument, right after the `chromium-browser \` line — Chromium does not care
# about flag order, so this only differs cosmetically from a fresh install.
BACKUP="${LAUNCHER}.bak.$(date +%Y%m%d%H%M%S)"
cp -a "$LAUNCHER" "$BACKUP"
log "Backed up launcher to $BACKUP"

TMP="$(mktemp)"
awk '
  { print }
  /^chromium-browser/ { print "  --password-store=basic \\" }
' "$LAUNCHER" > "$TMP"

# Verify the new content before touching the live file.
grep -qF -- "$FLAG" "$TMP" || { rm -f "$TMP"; die "patch produced no change; original untouched (backup at $BACKUP)."; }
bash -n "$TMP" 2>/dev/null || { rm -f "$TMP"; die "patched launcher is not valid bash; original untouched (backup at $BACKUP)."; }

# Overwrite in place (preserves the launcher's owner + mode; no chown needed).
cat "$TMP" > "$LAUNCHER"
rm -f "$TMP"
log "Flag inserted into $LAUNCHER."

# --- relaunch --------------------------------------------------------------
if [ "$NO_REBOOT" = "1" ]; then
  log "NO_REBOOT=1 — skipping reboot. Restart the kiosk session (or reboot) to apply."
  exit 0
fi
log "Rebooting to relaunch Chromium with the flag..."
sync
reboot
