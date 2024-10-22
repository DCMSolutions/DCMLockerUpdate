### BIENVENIDO AL DCM UPDATER ###

sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak

sudo mv /home/pi/'DCMLocker\Base'/LoackerConfig.config /home/pi/LoackerConfig.config
sudo mv /home/pi/'DCMLocker\Base'/LoackerMap.map /home/pi/LoackerMap.map

sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo reboot
