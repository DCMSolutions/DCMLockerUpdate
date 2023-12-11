sudo apt-get update
sudo apt-get install -y chromium-browser-l10n

#Borro archivo de arranque
sudo rm /etc/xdg/autostart/display.desktop

############ inicio en chromium ############
#creo archivo que da el arranque
sudo touch /etc/xdg/autostart/display.desktop
#doy permisos para modificar desde el script
sudo chmod ugo+rwx /etc/xdg/autostart/display.desktop
#modifico archivo y agrego instrucciones
echo "[Desktop Entry]
Name=KioskMode #name
Exec=chromium-browser --start-fullscreen --kiosk --app=http://localhost:5022/ --disable-pinch
" > /etc/xdg/autostart/display.desktop
