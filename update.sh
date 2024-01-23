### BIENVENIDO AL DCM UPDATER ###



sudo rm -r /home/pi/DCMLocker
sudo rm -r /home/pi/'DCMLocker\base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo systemctl restart dcmlocker
sudo reboot
