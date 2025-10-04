sudo rm -r /home/DCMLocker.bak
sudo mv /home/DCMLocker /home/DCMLocker.bak
sudo rm -r /home/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLastUbuntu /home/DCMLocker
sudo reboot --force --reboot
