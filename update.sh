### BIENVENIDO AL DCM UPDATER ###

############ inicio en chromium ############
# creo archivo que da el arranque
sudo touch /etc/xdg/autostart/display.desktop

# doy permisos para modificar desde el script
sudo chmod ugo+rwx /etc/xdg/autostart/display.desktop

# modifico archivo y agrego instrucciones
echo "[Desktop Entry]
Name=KioskMode #name
Exec=/bin/bash -c 'while ! systemctl is-active --quiet dcmlocker.service; do sleep 1; done; chromium-browser --start-fullscreen --kiosk --force-device-scale-factor=1 --app=http://localhost:5022/ --disable-pinch'
Type=Application
X-GNOME-Autostart-enabled=true
" > /etc/xdg/autostart/display.desktop

############ creo dcmlocker.service  ############
#creo archivo que da el arranque
sudo touch /etc/systemd/system/dcmlocker.service
#doy permisos para modificar desde el script
sudo chmod ugo+rwx /etc/systemd/system/dcmlocker.service
echo -e "[Unit]
Description=dcmlocker

[Service]
WorkingDirectory=/home/pi/DCMLocker
ExecStart=/opt/dotnet/dotnet /home/pi/DCMLocker/DCMLocker.Server.dll
Restart=always
SyslogIdentifier=dotnet-dcmlocker
User=root
Environment=ASPNETCORE_ENVIRONMENT=Production

[Install]
WantedBy=multi-user.target
" > /etc/systemd/system/dcmlocker.service

#creo servicio
sudo systemctl enable dcmlocker.service

#inico servicio
sudo systemctl start dcmlocker.service

#el xhost-setup fue para probar algo, se elimina
sudo rm /etc/systemd/system/xhost-setup.service


if [ ! -f /home/pi/LoackerConfig.config ]; then
    sudo cp /home/pi/'DCMLocker\Base'/LoackerConfig.config /home/pi/LoackerConfig.config
fi
if [ ! -f /home/pi/LoackerMap.map ]; then
    sudo cp /home/pi/'DCMLocker\Base'/LoackerMap.map /home/pi/LoackerMap.map
fi

#esto le da acceso a la app a modificar los archivos
sudo chown pi:pi /home/pi/LoackerMap.map
sudo chown pi:pi /home/pi/LoackerConfig.config

sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo reboot --force --reboot
