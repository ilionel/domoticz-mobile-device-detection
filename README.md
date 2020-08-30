# domoticz-mobile-device-detection
Determine if one or many devices (like smartphones) are reachable or not.
Check are done using Bluetooth (or Wifi detection) and the state are synced with Domoticz "virtuals switches"

## Warrning
Beta version !
This script are done for my home usage. It was only tested on my Raspberry and it's the first release of it.
Your are welcome to use it, but with precaution, your are advised !  

## Script Installation

```
cd domoticz/scripts
git clone https://github.com/ilionel/domoticz-mobile-device-detection
cd domoticz-mobile-device-detection
sudo chmod +x areDevicesAtHome.sh
sudo chmod +x domoticz-mobile-device-detection.sh
```

## Script Configuration
Personalize devices list :
```
nano areDevicesAtHome.sh
# List of devices like "devices[myPhone]='BT@Mac;Wifi@IP;DomitoczIDX'"
devices[iPhone]='ab:cd:ef:12:14:56;192.168.1.101;6001'
devices[Samsung]='12:14:56:ab:cd:ef;192.168.1.101;6002'
```
One line by device.
Syntaxe are : `'Bluetooth Mac Address;Device Home Fixed IP;Domitocz switch IDX'`


## Run as service

Check absolute path to "areDevicesAtHome.sh":
```
nano domoticz-mobile-device-detection.sh

DAEMON=/home/domoticz/scripts/domoticz-mobile-device-detection/areDevicesAtHome.sh

```

Add to system services:

```
# check your path here:
sudo ln -s /home/domoticz/scripts/domoticz-mobile-device-detection/domoticz-mobile-device-detection.sh /etc/init.d/domoticz-mobile-device-detection
# add to startup:
sudo update-rc.d domoticz-mobile-device-detection defaults
sudo systemctl daemon-reload

# check service status
sudo service domoticz-mobile-device-detection status

# to start
sudo service domoticz-mobile-device-detection start

# to stop
sudo service domoticz-mobile-device-detection stop

# if you want to delete from startup:
sudo update-rc.d -f domoticz-mobile-device-detection remove
```
