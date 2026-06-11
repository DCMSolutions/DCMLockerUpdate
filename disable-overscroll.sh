#!/usr/bin/env bash
#
# disable-overscroll.sh
# ---------------------
# One-shot retrofit for already-deployed Ubuntu/AlmaLinux STD lockers.
#
# Adds the Chromium flag that disables the touchscreen "swipe-right = go back"
# gesture (OverscrollHistoryNavigation / TouchpadOverscrollHistoryNavigation) to
# the kiosk launcher at /home/kiosk/.local/bin/gnome-kiosk-script.
#
# New installs already get this from `instalador ubuntu.txt`. This script exists
# because the launcher is written ONCE at install time and the normal app update
# (updateUbuntu.sh) only swaps the Blazor tarball — it never rewrites the
# launcher. So lockers installed before the flag was added need this patch.
#
# Run as root on the locker (reboots on success so Chromium relaunches):
#     sudo bash disable-overscroll.sh
#   or remotely:
#     wget -qO- https://raw.githubusercontent.com/DCMSolutions/DCMLockerUpdate/main/disable-overscroll.sh | sudo bash
#
# Env:
#   NO_REBOOT=1   patch only, don't reboot (restart the kiosk session by hand).
#
set -euo pipefail

LAUNCHER="/home/kiosk/.local/bin/gnome-kiosk-script"
# Keep this string in sync with the awk insert below.
FLAG="--disable-features=OverscrollHistoryNavigation,TouchpadOverscrollHistoryNavigation"
NO_REBOOT="${NO_REBOOT:-0}"

log() { printf '[disable-overscroll] %s\n' "$*"; }
die() { printf '[disable-overscroll] ERROR: %s\n' "$*" >&2; exit 1; }

# --- preconditions ---------------------------------------------------------
[ "$(id -u)" -eq 0 ] || die "must run as root (sudo bash disable-overscroll.sh)."
[ -f "$LAUNCHER" ]   || die "launcher not found at $LAUNCHER — is this an Ubuntu-line STD locker?"

# --- idempotency / conflict guard -----------------------------------------
# (FLAG starts with '--', so every grep that takes it as a pattern needs '--'.)
if grep -qF -- "$FLAG" "$LAUNCHER"; then
  log "Flag already present — nothing to do."
  exit 0
fi
if grep -q -- '--disable-features=' "$LAUNCHER"; then
  die "a different --disable-features= line already exists; merge by hand (Chromium honors only one)."
fi
grep -q '^chromium-browser' "$LAUNCHER" || die "no 'chromium-browser' launch line; launcher format unexpected, aborting."

# --- patch -----------------------------------------------------------------
# awk (not sed) because GNU sed's a/i backslash handling silently drops the
# trailing ' \' continuation on some versions, which would terminate the
# chromium-browser command early. awk string '\\' is exactly one backslash, so
# the inserted line keeps its line-continuation. Insert it as the first argument,
# right after the `chromium-browser \` line.
BACKUP="${LAUNCHER}.bak.$(date +%Y%m%d%H%M%S)"
cp -a "$LAUNCHER" "$BACKUP"
log "Backed up launcher to $BACKUP"

TMP="$(mktemp)"
awk '
  { print }
  /^chromium-browser/ { print "  --disable-features=OverscrollHistoryNavigation,TouchpadOverscrollHistoryNavigation \\" }
' "$LAUNCHER" > "$TMP"

# Verify the new content before touching the live file.
grep -qF -- "$FLAG" "$TMP" || { rm -f "$TMP"; die "patch produced no change; original untouched (backup at $BACKUP)."; }

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
