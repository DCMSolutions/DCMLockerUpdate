sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
cd /home/pi/DCMLocker
sudo git checkout -f 9ef27884b7e8b1592b68711ca98397c2c7b15f6c
sudo reboot
