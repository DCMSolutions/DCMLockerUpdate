#!/usr/bin/env bash
set -euo pipefail

sudo find /home -maxdepth 1 -type f -name 'eventos-*' -print -delete

sudo rm -rf /home/DCMLockerLastUbuntu

sudo git clone https://github.com/DCMSolutions/DCMLockerLastUbuntu.git /home/DCMLockerLastUbuntu

sleep 1

sudo reboot
