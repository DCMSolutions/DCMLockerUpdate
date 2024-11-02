### BIENVENIDO AL DCM UPDATER ###

sudo rm -r /home/pi/DCMLocker.bak

sudo cp /home/pi/'DCMLocker\Base'/LoackerConfig.config /home/pi/LoackerConfig.config
sudo cp /home/pi/'DCMLocker\Base'/LoackerMap.map /home/pi/LoackerMap.map

sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker

sudo cp /home/pi/LoackerConfig.config /home/pi/'DCMLocker\Base'/LoackerConfig.config
sudo cp /home/pi/LoackerMap.map /home/pi/'DCMLocker\Base'/LoackerMap.map

sudo reboot
