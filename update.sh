### BIENVENIDO AL DCM UPDATER ###

############ creo xhost-setup.service  ############
#creo archivo que da el arranque
sudo touch /etc/systemd/system/xhost-setup.service
#doy permisos para modificar desde el script
sudo chmod ugo+rwx /etc/systemd/system/xhost-setup.service
echo -e "[Unit]
Description=Allow root access to X server
After=graphical.target
Requires=graphical.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c "sleep 10 && DISPLAY=:0 XAUTHORITY=/home/pi/.Xauthority /usr/bin/xhost +SI:localuser:root"
User=pi

[Install]
WantedBy=graphical.target
" > /etc/systemd/system/xhost-setup.service

#creo servicio
sudo systemctl enable xhost-setup.service

#inico servicio
sudo systemctl start xhost-setup.service

############ creo dcmlocker.service  ############
#creo archivo que da el arranque
sudo touch /etc/systemd/system/dcmlocker.service
#doy permisos para modificar desde el script
sudo chmod ugo+rwx /etc/systemd/system/dcmlocker.service
echo -e "[Unit]
Description=dcmlocker
After=xhost-setup.service
Requires=xhost-setup.service

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

if [ ! -f /home/pi/LoackerConfig.config ]; then
    sudo cp /home/pi/'DCMLocker\Base'/LoackerConfig.config /home/pi/LoackerConfig.config
fi
if [ ! -f /home/pi/LoackerMap.map ]; then
    sudo cp /home/pi/'DCMLocker\Base'/LoackerMap.map /home/pi/LoackerMap.map
fi

#esto le da acceso a la app a modificar los archivos
sudo chown pi:pi /home/pi/LoackerMap.map
sudo chown pi:pi /home/pi/LoackerConfig.config

#esto mata el servicio que abria anteriormente el chromium
sudo rm -f /etc/xdg/autostart/display.desktop
sudo rm -f /etc/xdg/autostart/display.desktop.save

sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo reboot --force --reboot
