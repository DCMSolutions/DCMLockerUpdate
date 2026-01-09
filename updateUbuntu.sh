#!/usr/bin/env bash
set -euo pipefail

find /home -maxdepth 1 -type f -name 'eventos-*' -print -delete

rm -rf /home/DCMLockerLastUbuntu

git clone https://github.com/DCMSolutions/DCMLockerLastUbuntu.git /home/DCMLockerLastUbuntu

sleep 1

reboot
