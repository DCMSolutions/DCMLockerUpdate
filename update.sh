### BIENVENIDO AL DCM UPDATER ###

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
