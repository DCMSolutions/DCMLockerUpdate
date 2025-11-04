#!/usr/bin/env bash

cd /home || exit 1

rm -rf /home/DCMLocker.bak
[ -d /home/DCMLockerLastUbuntu ] && mv /home/DCMLockerLastUbuntu /home/DCMLocker.bak || true

rm -rf /home/'DCMLockerLastUbuntu\Base' || true

git clone --depth 1 https://github.com/DCMSolutions/DCMLockerLastUbuntu /home/DCMLockerLastUbuntu

nohup bash -c 'sleep 2; reboot' >/dev/null 2>&1 &
