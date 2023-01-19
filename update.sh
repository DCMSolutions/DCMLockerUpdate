### BIENVENIDO AL DCM UPDATER ###



#Se chequea si algunas carpetas existen, y en ese caso, las borro.

if [ -d "/home/pi/DCMLocker" ]
then
   sudo rm -r /home/pi/DCMLocker
else
   echo "El directorio ${DIRECTORIO} no existe"
fi

if [ -d "/home/pi/'DCMLocker\base'" ]
then
   sudo rm -r /home/pi/'DCMLocker\base'
else
   echo "El directorio ${DIRECTORIO} no existe"
fi

sudo git clone https://github.com/Ansel-dal/DCMLocker

sudo systemctl restart dcmlocker
sudo reboot
