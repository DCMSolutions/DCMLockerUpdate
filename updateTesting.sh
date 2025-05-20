echo "[Desktop Entry]
Name=KioskMode
Exec=/bin/bash -c 'PROFILE_DIR=\$(mktemp -d -t kiosk-profile-XXXXXX) && sleep 5 && chromium-browser --start-fullscreen --kiosk --force-device-scale-factor=1 --user-data-dir=\"\$PROFILE_DIR\" --app=http://localhost:5022/ --disable-pinch'
Type=Application
X-GNOME-Autostart-enabled=true
" | sudo tee /etc/xdg/autostart/display.desktop > /dev/null


sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone --branch testing https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo reboot --force --reboot
