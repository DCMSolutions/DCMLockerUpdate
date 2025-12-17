#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="/home/DCMLockerLastUbuntu"
TMP="/home/.dcmlocker_tmp"

systemctl stop dcmlocker.service || true

rm -rf "$TMP"
mkdir -p "$TMP"

[ -f "$TARGET_DIR/configjson.json" ] && mv "$TARGET_DIR/configjson.json" "$TMP/" || true
[ -d "$TARGET_DIR/eventos" ] && mv "$TARGET_DIR/eventos" "$TMP/" || true

cd "$TARGET_DIR"
git fetch --prune --depth=1 origin
REF="$(git symbolic-ref -q --short refs/remotes/origin/HEAD || true)"
[ -z "${REF:-}" ] && REF="origin/main"
git reset --hard "$REF"
git clean -fd

rm -rf "$TARGET_DIR/eventos"
mkdir -p "$TARGET_DIR/eventos"
[ -d "$TMP/eventos" ] && mv "$TMP/eventos" "$TARGET_DIR/eventos" || true
[ -f "$TMP/configjson.json" ] && mv "$TMP/configjson.json" "$TARGET_DIR/configjson.json" || true

if [ ! -f "$TARGET_DIR/configjson.json" ] && [ -f "$TARGET_DIR/configjson.json.sample" ]; then
  cp "$TARGET_DIR/configjson.json.sample" "$TARGET_DIR/configjson.json"
fi

if [ -f "$TARGET_DIR/configjson.json" ] && ! grep -q '"Modo"' "$TARGET_DIR/configjson.json" && grep -q '"IsAssets"' "$TARGET_DIR/configjson.json"; then
  sed -i -E 's/"IsAssets"[[:space:]]*:[[:space:]]*true/"Modo": "Assets"/; s/"IsAssets"[[:space:]]*:[[:space:]]*false/"Modo": "Tokens"/' "$TARGET_DIR/configjson.json"
fi

rm -f "$TARGET_DIR/appsettings.Development.json" "$TARGET_DIR/configjson.Development.json"
rm -rf "$TARGET_DIR/BlazorDebugProxy"
rm -f "$TARGET_DIR/configjson.json.sample"

rm -f /home/eventos-*.ans

rm -rf "$TMP"

nohup bash -c 'sleep 2; reboot' >/dev/null 2>&1 &
