#!/bin/bash
declare -r domoticzserverip='192.168.0.1'
declare -A devices # Array of device list

# List of devices like "devices[myPhone]='BT@Mac;Wifi@IP;DomitoczIDX'"
devices[iPhone]='ab:cd:ef:12:14:56;192.168.1.101;6001'
devices[Samsung]='12:14:56:ab:cd:ef;192.168.1.101;6002'


declare -A domoticzStatus

declare -a -r switch=(Off On)

declare -i -r DEFAULT_TIMEOUT=1
declare -i -r DEFAULT_INTERVAL=1
declare -i -r DEFAULT_DELAY=5

# Timeout. (in seconds)
declare -i timeout=DEFAULT_TIMEOUT

# Interval (in seconds) between 1st and 2nd check
declare -i interval=DEFAULT_INTERVAL

# Delay between posting the SIGTERM signal and destroying the process by SIGKILL.
declare -i delay=DEFAULT_DELAY

# if Boolean = 1 -> don't stop scanning
declare -i loop=0

declare -i currentIDX=0

scriptName="${0##*/}"

arglist=$*

function printUsage() {
    cat <<EOF

Synopsis
    $scriptName [-h] [-t timeout] [-i interval] [-l [-d delay]]
    Check if specifics devices are unreachable and update
    Domoticz if needed.

    -h Print this Help.

    -t timeout
        Number of seconds to wait for ping completion.
        Default value: $DEFAULT_TIMEOUT seconds.

    -i interval
        Interval between 1st and 2nd test.
        Positive integer, default value: $DEFAULT_INTERVAL seconds.

    -l (for loop)
       Scan in loop $scriptName will operate until interrupted

    -d delay
        Time to wait before rescan for device
        process by SIGKILL. Default value: $DEFAULT_DELAY seconds.

    -q (for quiet)
       Turn off $scriptName’s output.

As of today, Bash does not support floating point arithmetic (sleep does),
therefore all delay/time values must be integers.
EOF
}

# Options.
while getopts ":ht:i:ld:q" option; do
    case "$option" in
        h) help=1 ;;
        t) timeout=$OPTARG ;;
        i) interval=$OPTARG ;;
        l) loop=1 ;;
        d) delay=$OPTARG ;;
        q) quiet=1 ;;
        *) printUsage; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

# $# should be at least 1 (the command to execute), however it may be strictly
# greater than 1 if the command itself has options.
if ((help == 1 || timeout <= 0 || interval <= 0 || delay <= 0)); then
    printUsage
    exit 1
fi

function checkAvailability() {
  IFS=";" read -r -a arr <<< "$1"
  # Set Parameters
  local name="${device}"
  local bluetoothmac="${arr[0]}"
  local IP="${arr[1]}"
  currentIDX="${arr[2]}"

  for i in "1st" "2nd"
  do
    if [ ! -z ${bluetoothmac} ] && l2ping -c1 -t${timeout} "${bluetoothmac}" > /dev/null 2>&1 ; then
      [ -z $quiet ] && echo "$(date --iso-8601=seconds) - $name is reachable thanks to Bluetooth (at $i attempt)"
      return 1
    elif [ ! -z ${IP} ] && ping -c1 -W${timeout} "${IP}" > /dev/null 2>&1 ; then
      [ -z $quiet ] && echo "$(date --iso-8601=seconds) - $name is reachable thanks to Wifi (at $i attempt)"
      return 1
    else
      [ -z $quiet ] && echo "$(date --iso-8601=seconds) - $name is unreachable"
      return 0
    fi
    sleep ${interval}
  done
}

function checkDomoticzStatus() {
  local -r IDX=$1
  # Check Online / Offline state of Domoticz device
  if [ -z ${domoticzStatus["$IDX"]} ]; then
    domoticzStatus["$IDX"]=$(curl -s "http://"$domoticzserverip"/json.htm?type=devices&rid="$IDX"" | grep '"Data" :' | awk '{ print $3 }' | sed 's/[!@#\$%",^&*()]//g')
  fi
  if [ ${domoticzStatus["$IDX"]} = "On" ]; then return 1
  elif [ ${domoticzStatus["$IDX"]} = "Off" ]; then return 0
  else return -1
  fi
}

function updateDomoticzStatus() {
  local -r IDX=$1
  local -r -i boolstatus=$2
  updatesatus=$(curl -s "http://"$domoticzserverip"/json.htm?type=command&param=switchlight&idx="$IDX"&switchcmd=${switch[$boolstatus]}" | grep '"status" :' | awk '{ print $3 }' | sed 's/[!@#\$%",^&*()]//g')
  if [ $updatesatus = "OK" ]; then
    domoticzStatus["$IDX"]=${switch[$boolstatus]}
    return 0
  else return -1
  fi
}

function syncWithDomoticz() {
  local -r IDX=$1
  local -r -i boolstatus=$2
  checkDomoticzStatus $1
  local -r -i booldomoticzstatus=$?
  # Compare ping result to Domoticz device status
  if [ $boolstatus -eq $booldomoticzstatus ] ; then
    [ -z $quiet ] && echo "$(date --iso-8601=seconds) - Status \"${switch[$boolstatus]}\" is allready sync with Domoticz"
    return 0
  else
    [ -z $quiet ] && echo "$(date --iso-8601=seconds) - Domoticz status is out of sync, correcting..."
    [ -z $quiet ] && echo "$(date --iso-8601=seconds) - Update Domoticz (idx $IDX) status to \"${switch[$boolstatus]}\""
    updateDomoticzStatus $IDX $boolstatus
    local syncstatus=$?
   if [ $syncstatus -eq 0 ]; then
     [ -z $quiet ] && echo "$(date --iso-8601=seconds) - Successfully upgrade status"
     return 0
   else
     [ -z $quiet ] && echo "$(date --iso-8601=seconds) - Error during Domoticz status upgrade!!"
     return -1
   fi
  fi
}

function syncDevicesAvailabilityWithDomoticz() {
  local -i syncedDevices=0
  for device in "${!devices[@]}"
  do
    checkAvailability "${devices[$device]}"
    status=$?
    syncWithDomoticz $currentIDX $status
    [ $? -eq 0 ] && (( syncedDevices++ ))
  done
  if [ ${#devices[@]} -eq $syncedDevices ]; then
    [ -z $quiet ] && echo "$(date --iso-8601=seconds) - Done! All devices status was successfully synced."
     return 0
   else
     local -i -r numOfErr=$((${#devices[@]}-$syncedDevices))
     [ -z $quiet ] && echo "$(date --iso-8601=seconds) - $numOfErr error(s) occured during synchronization :-(("
     return $numOfErr
  fi
}

function loop() {
  while [ 1 ]
  do
    $0 "${arglist//-l/} &"
    wait $!
    sleep $delay
  done
}

[ $loop -eq 1  ] && loop || syncDevicesAvailabilityWithDomoticz
