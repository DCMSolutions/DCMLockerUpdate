sudo rm -r /home/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLastUbuntu /home/pi/DCMLocker
sudo reboot --force --reboot
