#!/usr/bin/env bash
set -euo pipefail #esto es para que cualquier error te saque del comando, no se si lo quiero o no, para pensar 

TARGET_DIR="/home/DCMLockerLastUbuntu"

git -C "$TARGET_DIR" fetch --depth=1 origin
git -C "$TARGET_DIR" reset --hard origin/HEAD

mkdir -p "$TARGET_DIR/eventos"

if [ ! -f "$TARGET_DIR/configjson.json" ] && [ -f "$TARGET_DIR/configjson.json.sample" ]; then
  cp "$TARGET_DIR/configjson.json.sample" "$TARGET_DIR/configjson.json"
fi

nohup bash -c 'sleep 2; reboot' >/dev/null 2>&1 &
