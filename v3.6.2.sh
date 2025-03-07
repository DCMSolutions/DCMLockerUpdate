sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
cd /home/pi/DCMLocker
sudo git checkout -f 49c00de2a4dcf367d8b15d6d4f97f6ef64a820bf
sudo reboot
