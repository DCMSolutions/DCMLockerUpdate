#!/usr/bin/env bash
set -euo pipefail

cd /home/DCMLockerLastUbuntu
gil pull

nohup bash -c 'sleep 2; reboot' >/dev/null 2>&1 &
