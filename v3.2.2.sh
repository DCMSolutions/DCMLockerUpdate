sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
cd /home/pi/DCMLocker
git checkout 8e22b6029f52858ce64367433d88423b6ae1a63c
sudo reboot
