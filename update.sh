#temporal para pantalla blanca

# modifico archivo y agrego instrucciones
echo "[Desktop Entry]
Name=KioskMode
Exec=/home/pi/kiosk-launcher.sh
Type=Application
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=5
" > /etc/xdg/autostart/display.desktop

# creo el archivo ejecutable que abre el chromium
cat << 'EOF' > /home/pi/kiosk-launcher.sh
#!/bin/bash
chromium-browser file:///home/pi/reloader.html --kiosk --start-fullscreen --force-device-scale-factor=1 --disable-pinch
EOF

# doy permisos de ejecucion
chmod +x /home/pi/kiosk-launcher.sh

# creo la pagina falsa que redirije
cat << 'EOF' > /home/pi/reloader.html
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8" />
  <meta http-equiv="refresh" content="5;url=http://localhost:5022" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cargando Aplicación...</title>
  <style>
    body {
      background-color: #ffffff;
      color: #000000;
      font-family: Arial, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
    }

    h1 {
      font-size: 2.5rem;
      margin-bottom: 10px;
    }

    p {
      font-size: 1.2rem;
      opacity: 0.8;
    }

    .spinner {
      margin-top: 30px;
      width: 40px;
      height: 40px;
      border: 4px solid #ccc;
      border-top: 4px solid #00bfff;
      border-radius: 50%;
      animation: spin 1s linear infinite;
    }

    @keyframes spin {
      to { transform: rotate(360deg); }
    }
  </style>
</head>
<body>
  <h1>Cargando Aplicación...</h1>
  <p>Serás redirigido automáticamente</p>
  <div class="spinner"></div>
</body>
</html>
EOF


sudo rm -r /home/pi/DCMLocker.bak
sudo mv /home/pi/DCMLocker /home/pi/DCMLocker.bak
sudo rm -r /home/pi/'DCMLocker\Base'
sudo git clone https://github.com/DCMSolutions/DCMLockerLast /home/pi/DCMLocker
sudo reboot --force --reboot
