sudo rm -r /home/pi/DCMLocker.bak

sudo cp /home/pi/'DCMLocker\Base'/LoackerConfig.config /home/pi/LoackerConfig.config
sudo cp /home/pi/'DCMLocker\Base'/LoackerMap.map /home/pi/LoackerMap.map

sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
cd /home/pi/DCMLocker
sudo git checkout -f 9ef27884b7e8b1592b68711ca98397c2c7b15f6c

sudo cp /home/pi/LoackerConfig.config /home/pi/'DCMLocker\Base'/LoackerConfig.config
sudo cp /home/pi/LoackerMap.map /home/pi/'DCMLocker\Base'/LoackerMap.map

sudo reboot
