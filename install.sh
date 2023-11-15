sudo apt-get update
sudo apt install nginx -y
sudo service nginx start
sudo apt install rpi-eeprom rpi-eeprom-images -y

#configuraciones de red
echo -e "
interface eth0
metric 303
static ip_address=192.168.2.3
static routers=192.168.2.1
static domain_name_servers=192.168.2.1
interface wlan0
metric 200
" >> /etc/dhcpcd.conf

#Instalar repositorio de la aplicación

sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker

#instalar net 5
sudo wget -O - https://raw.githubusercontent.com/pjgpetecodes/dotnet5pi/master/install.sh | sudo bash

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

############ inicio en chromium ############
#creo archivo que da el arranque
sudo touch /etc/xdg/autostart/display.desktop
#doy permisos para modificar desde el script
sudo chmod ugo+rwx /etc/xdg/autostart/display.desktop
#modifico archivo y agrego instrucciones
echo "[Desktop Entry]
Name=KioskMode #name
Exec=chromium-browser --start-fullscreen --force-device-scale-factor=0.7 --kiosk --app=http://localhost:5022/
" > /etc/xdg/autostart/display.desktop

sudo reboot
