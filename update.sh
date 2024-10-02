### BIENVENIDO AL DCM UPDATER ###

sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo apt update 
sudo apt upgrade chromium-browser -y
sudo reboot
