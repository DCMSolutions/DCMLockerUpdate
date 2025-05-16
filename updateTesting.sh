echo "[Desktop Entry]
Name=KioskMode #name
Exec=/bin/bash -c 'PROFILE_DIR=$(mktemp -d -t kiosk-profile-XXXXXX) && sleep 5 &&  chromium-browser --start-fullscreen --kiosk --force-device-scale-factor=1 --user-data-dir="$PROFILE_DIR" --app=http://localhost:5022/ --disable-pinch'
Type=Application
X-GNOME-Autostart-enabled=true
" > /etc/xdg/autostart/display.desktop

sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone --branch testing https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo reboot --force --reboot
