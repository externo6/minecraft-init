#!/bin/bash
# /etc/init.d/minecraft
# version 2012-04-26 (YYYY-MM-DD)
# Luke Hanley
# Dependencies: screen zip
 
### BEGIN INIT INFO
# Provides: minecraft
# Required-Start: $local_fs $remote_fs
# Required-Stop: $local_fs $remote_fs
# Should-Start: $network
# Should-Stop: $network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Short-Description: Minecraft server
# Description: Starts the CraftBukkit Minecraft server
### END INIT INFO
 
# Source function library
. /etc/rc.d/init.d/functions
 
## Settings
# Nice looking name of service for script to report back to users
SERVERNAME="CraftBukkit"
# Filename of server binary
SERVICE="craftbukkit.jar"
# Username of non-root user who will run the server
USERNAME="bukkit"
# Path of server binary and world
MCPATH="/home/bukkit/craftbukkit"
# Number of CPU cores to thread across if using multithreaded garbage collection
CPU_COUNT=2

# Location where to perform backups
BACKUPPATH="/home/bukkit/backups/"
# Location of worlds to backup. Simple txt file with wotrld names separted by spaces. This will also be outputted when running the info command.
worldlist="$(/bin/cat /home/bukkit/craftbukkit/backupworld.txt)"
# Extension of backups. (Leave .zip)
ext=.zip

  
 declare -a worlds=($worldlist)
 numworlds=${#worlds[@]}
 
## The Java command to run the server
 
# Nothing special, just start the server.
# INVOCATION="java -Xms3072M -Xmx3072M -Djava.net.preferIPv4Stack=true -jar $SERVICE nogui"
 
# Tested fastest. Default parallel new gen collector, plus parallel old gen collector.
INVOCATION="java -Xms1400M -Xmx1400M -Djava.net.preferIPv4Stack=true -XX:MaxPermSize=256M -XX:UseSSE=2 -XX:-DisableExplicitGC -XX:+UseParallelOldGC -XX:ParallelGCThreads=$CPU_COUNT -jar $SERVICE nogui"
 
# removed "performance" commands
# -XX:+UseFastAccessorMethods -XX:+AggressiveOpts -XX:+UseAdaptiveGCBoundary
 
# Escape code
esc=`echo -en "\033"`

# Set colors
cc_red="${esc}[0;31m"
cc_green="${esc}[0;32m"
cc_yellow="${esc}[0;33m"
cc_blue="${esc}[0;34m"
cc_normal=`echo -en "${esc}[m\017"`
## Usage ${cc_green}
 
## Runs all commands as the non-root user
 
as_user() {
  ME=`whoami`
  if [ $ME == $USERNAME ] ; then
    bash -c "$1"
  else
    su - $USERNAME -c "$1"
  fi
}
 
## Start the server executable as a service
 
mc_start() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    PID="`ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE | awk '{print $1}'`"
    failure && echo " * $SERVERNAME was already running! (pid $PID)"
    exit 1;
  else
    echo " * $SERVERNAME was not already running. Starting..."
    echo " * Using worlds named \"$worldlist\"..."
    cd $MCPATH
    as_user "cd $MCPATH && screen -dmS minecraft $INVOCATION"
    sleep 10
    echo " * Checking $SERVERNAME is running..."
 
    if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
    then
      PID="`ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE | awk '{print $1}'`"
      success && echo " * $SERVERNAME is now running. (pid $PID)"
    else
      failure && echo " * Could not start $SERVERNAME."
      exit 1; 
    fi
 
  fi
}
 
## Stop the executable
 
mc_stop() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    PID="`ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE | awk '{print $1}'`"
    echo " * $SERVERNAME is running (pid $PID). Commencing shutdown..."
    echo " * Notifying users of shutdown..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say SERVER SHUTTING DOWN IN 10 SECONDS. Saving map...\"\015'"
    echo " * Saving worlds named \"$worldlist\" to disk..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
    sleep 10
    echo " * Stopping $SERVERNAME..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"stop\"\015'"
    sleep 10
  else
    failure && echo " * $SERVERNAME was not running!"
	echo "Exiting, please start the server first!"
    exit 1;
  fi
 
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    failure && echo " * $SERVERNAME could not be shutdown! Still running..."
    exit 1;
  else
    success && echo " * $SERVERNAME is shut down."
  fi
}
 
 
## Set the server read-only, save the map, and have Linux sync filesystem buffers to disk
 
mc_saveoff() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo " * $SERVERNAME is running. Commencing save..."
    echo " * Notifying users of save..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say Starting multiworld save...\"\015'"
    echo " * Setting server read-only..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-off\"\015'"
    echo " * Saving worlds to disk..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-all\"\015'"
    sync
    sleep 10
    success && echo " * Worlds saved to disk."
  else
    failure && echo "$SERVERNAME was not running. Not suspending saves."
  fi
}
 
## Set the server read-write
 
mc_saveon() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    echo " * $SERVERNAME is running. Re-enabling saves..."
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"say Worlds saved.\"\015'"
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"save-on\"\015'"
  else
    failure && echo " * $SERVERNAME was not running. Not resuming saves."
  fi
}
 

## Backs up world by zipping it to the backup directory
 
mc_backupmap() {

hdateformat=$(date '+%Y-%m-%d-%H-%M-%S')H$ext
ddateformat=day/$(date '+%Y-%m-%d')D$ext

echo "Starting multiworld backup..."
    if [ -d $BACKUPPATH ] ; then
        sleep 0
    else
        as_user "mkdir -p $BACKUPPATH"
    fi
    as_user "cd $MCPATH && zip $BACKUPPATH$hdateformat -r backupworld.txt"
    as_user "cd $MCPATH && zip $BACKUPPATH$hdateformat -r server.properties"
    for ((i=0;i<$numworlds;i++)); do
        as_user "cd $MCPATH && zip $BACKUPPATH$hdateformat -r ${worlds[$i]}"
        echo "Saving '${worlds[$i]}' to '$BACKUPPATH$hdateformat'."
		echo
    done
	echo "Backup complete."
    as_user "cp $BACKUPPATH$hdateformat $BACKUPPATH$ddateformat"
    echo "Updated daily backup."
}
 
## Backs up everything by zipping it to the backup directory
 
mc_backupall() {

alldateformat=all/$(date '+%Y-%m-%d')A$ext

echo "Starting multiworld backup..."
    if [ -d $BACKUPPATH ] ; then
        sleep 0
    else
        as_user "mkdir -p $BACKUPPATH"
    fi
	as_user "cd $MCPATH && zip $BACKUPPATH$alldateformat -r *"
	echo "Full Minecraft Backup Complete"
 
}

## Remove old backups
mc_removeoldbackups() {

    find $BACKUPPATH/ -name *H$ext -mtime +0 -exec rm {} \;
    find $BACKUPPATH/day/ -name *D$ext -mtime +14 -exec rm {} \;
    find $BACKUPPATH/all/ -name *A$ext -mtime +28 -exec rm {} \;
    echo "Old Backups removed"
}

## Rotates logfile to server.0 through server.7, designed to be called by daily cron job
 
mc_logrotate() {
  # Server logfiles in reverse chronological order
  LOGLIST=$(ls -tr $MCPATH/server.log* | grep -v lck)
  # How many logs to keep
  COUNT=6
  # Look at all the logfiles
  for i in $LOGLIST; do
    LOGTMP=$(ls $i | cut -d "." -f 3)
	
    # If we're working with server.log then append .0
    if [ -z $LOGTMP ]
    then
      LOGTMP=$MCPATH"/server.log"
      LOGNEW=$LOGTMP".0"
      as_user "/bin/cp $MCPATH"/server.log" "$LOGNEW""
    # Otherwise, check if the file number is under $COUNT
    elif [ $LOGTMP -gt $COUNT ];
    then
      # If so, delete it
      as_user "rm -f $i"
    else
      # Otherwise, add one to the number
      LOGBASE=$(ls $i | cut -d "." -f 1-2)
      LOGNEW=$LOGBASE.$(($LOGTMP+1))
      as_user "/bin/cp $i $LOGNEW"
    fi
  done
  # Blank the existing logfile to renew it
  hdateformat=$(date '+%Y-%m-%d-%H-%M-%S')
  as_user "echo -n \"\" > $MCPATH/server.log"
  as_user "echo File Rotated at $hdateformat >> $MCPATH/server.log"
}
 
## Check if server is running and display PID
 
mc_status() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    PID="`ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE | awk '{print $1}'`"
    echo " * $SERVERNAME (pid $PID) is running..."
  else
    echo " * $SERVERNAME is not running."
    exit 1; # keep this exit in here so info doesn't run if server isn't active
  fi
}
 
## Display some extra informaton
 
mc_info() {
  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
    PID="`ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE | awk '{print $1}'`"
    JAVAPATH="`alternatives --display java | grep currently | cut -d " " -f 6`"
    RSS="`ps -p $PID --format rss | tail -n 1`"
    echo " - Java Path          : "$JAVAPATH""
    echo " - Start Command      : "$INVOCATION""
    echo " - Server Path        : "$MCPATH""
    echo " - World Names        : ${cc_green}"$worldlist"${cc_normal}"
    echo " - Process ID        : "$PID""
    echo " - Memory Usage      : `expr $RSS / 1024` Mb ($RSS kb)"
    echo
    echo " - Lag Mem : "
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"lagmem\"\015'"
    sleep 1
    tail $MCPATH/server.log | grep -m 1 "TPS"
    tail $MCPATH/server.log | grep -m 1 "free"
    echo
    echo " - Active Connections : "
    netstat -tna | grep -E "Proto|25565"
    echo
    echo " - Online Players : "
    as_user "screen -p 0 -S minecraft -X eval 'stuff \"list\"\015'"
    sleep 1
    tail $MCPATH/server.log | grep -m 1 "There are"
    tail $MCPATH/server.log | grep -m 1 "Connected"
  else
    echo " * $SERVERNAME is not running."
  fi
}

## Access console
 
mc_console() {

  if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
  then
     ME=`whoami`
    if [ $ME == $USERNAME ] ; then
     clear
     echo "${cc_red}STOP AND READ"
     echo
     echo "Also bug Luke to get this finished."
     echo
     echo "${cc_normal}PLEASE! ${cc_red}DEATTACH from the screen ${cc_normal}after you have finished!"
     echo
     echo "${cc_green}Do this by Pressing${cc_red} Ctrl-A then Ctrl-D ${cc_normal}"
     echo
     echo "or just close the window..."
     sleep 6
     echo
     echo
     echo
     as_user "screen -x minecraft"
  else
#     clear
#     echo "${cc_red}STOP AND READ"
#     echo
#     echo "Also bug Luke to get this finished."
#     echo
#     echo "${cc_normal}PLEASE! ${cc_red}DEATTACH from the screen ${cc_normal}after you have finished!"
#     echo
#     echo "${cc_green}Do this by Pressing${cc_red} Ctrl-A then Ctrl-D ${cc_normal}"
#    echo
#    echo "or just close the window..."
#    sleep 3
#    echo
#    echo
#    echo
    screen -x MinecraftConsole
    exit
  fi
  
  else
    echo " * $SERVERNAME is not running."
    exit 1; # keep this exit in here so info doesn't run if server isn't active
  fi
}

## Start root console screen
 
mc_consolestart() {
  ME=`whoami`
   if [ $ME == root ] ; then
    screen -dmS MinecraftConsole su $USERNAME
    sleep 1
    screen -p 0 -S MinecraftConsole -X stuff "script /dev/null$(printf \\r)"
    sleep 1
    screen -p 0 -S MinecraftConsole -X stuff "screen -x minecraft$(printf \\r)"
  else
    echo "${cc_red}NOT ROOT"
    echo "${cc_red}Please enter root password or remote console will stop working."
    echo "You will have to enter it three times!${cc_normal}"
    su - root -c "screen -dmS MinecraftConsole su $USERNAME"
    sleep 1
    echo "${cc_red}And again...${cc_normal}"
    su - root -c "screen -p 0 -S MinecraftConsole -X stuff \"script /dev/null$(printf \\r)\""
    sleep 1
    echo "${cc_red}Last time...${cc_normal}"
    su - root -c "screen -p 0 -S MinecraftConsole -X stuff \"screen -x minecraft$(printf \\r)\""
  fi
  
}

## Stop any root console screen named "MinecraftConsole"
 
mc_consolestop() {
  ME=`whoami`
   if [ $ME == root ] ; then
    for session in $(screen -ls | grep -o '[0-9]*\.MinecraftConsole'); do screen -S "${session}" -X quit; done
  else
    echo "${cc_red}NOT ROOT"
    echo "${cc_red}Please enter root password or remote console will stop working."
    echo "You will have to enter it one time!${cc_normal}"
    su - root -c "screen -X -S MinecraftConsole kill"
  fi
  
}

## Restart root console screen (this allows already connected screen

mc_consolerestart() {
  ME=`whoami`
   if [ $ME == root ] ; then
    screen -p 0 -S MinecraftConsole -X stuff "screen -x minecraft$(printf \\r)"
  else
    echo "${cc_red}NOT ROOT"
    echo "${cc_red}Please enter root password or remote console will stop working."
    echo "You will have to enter it one time!${cc_normal}"
    su - root -c "screen -p 0 -S MinecraftConsole -X stuff \"screen -x minecraft$(printf \\r)\""
  fi
  
}


## TODO: clear these up so the request for log lines can be made from the shell. Eg. "mc log 50" or "mc log 125"
 
mc_log() {
 as_user "tail -n 25 $MCPATH/server.log"
 echo
 echo "Last 25 lines of log"
}

mc_log50() {
 as_user "tail -n 50 $MCPATH/server.log"
 echo
 echo "Last 50 lines of log"
}
mc_logrecent() {
 tail -n 50 $MCPATH/server.log | awk '/entity|conn/ {sub(/lost/,"disconnected");print $1,$2,$4,$5}'
 echo
 echo "User connections/disconnections from last 50 lines of log"
}
mc_livelog() {
 echo
 tail -n 25 -f $MCPATH/server.log
}
mc_lagmem() {
 as_user "screen -p 0 -S minecraft -X eval 'stuff \"lagmem\"\015'"
 sleep 1
 tail $MCPATH/server.log | grep -m 1 "TPS"
 tail $MCPATH/server.log | grep -m 1 "free"
}
mc_list() {
 as_user "screen -p 0 -S minecraft -X eval 'stuff \"list\"\015'"
 sleep 1
 tail $MCPATH/server.log | grep -m 1 "There are"
 tail $MCPATH/server.log | grep -m 1 "Connected"
}

## These are the parameters passed to the script
 
case "$1" in
  start)
mc_start
mc_consolestart
;;
  stop)
mc_stop
mc_consolestop
;;
  restart)
mc_stop
mc_start
mc_consolerestart
;;
  backupmap)
mc_saveoff
mc_backupmap
mc_saveon
;;
  backupall)
mc_saveoff
mc_backupall
mc_saveon
;;
  status)
mc_status
;;
  info)
mc_status
mc_info
;;
  log)
mc_log
;;
  log50)
mc_log50
;;
  recent)
mc_logrecent
;;
  console)
mc_console
;;
  live)
mc_livelog
;;
  cdplugins)
mc_cdplugins
;;
  consoleflush)
mc_consolestop
mc_consolestart
;;
  list)
mc_list
;;
  lagmem)
mc_lagmem
;;
# These are intended for cron usage, not regular users.
  removeoldbackups)
mc_removeoldbackups
;;
# These are intended for cron usage, not regular users.
  logrotate)
mc_logrotate
;;
  *)
echo "${cc_green} * Usage: minecraft {${cc_red}command${cc_green}} * ${cc_normal}"
echo "${cc_red}start ${cc_normal}- Start $SERVERNAME server."
echo "${cc_red}stop ${cc_normal}- Stop $SERVERNAME server."
echo "${cc_red}restart ${cc_normal}- Restart $SERVERNAME server."
echo "${cc_red}status ${cc_normal}- Current running status of $SERVERNAME server."
echo "${cc_red}console ${cc_normal}- Access console for $SERVERNAME server."
echo "${cc_red}info ${cc_normal}- Show more information for $SERVERNAME server."
echo "${cc_red}list ${cc_normal}- Show list of currently online players."
echo "${cc_red}recent ${cc_normal}- Show recent connections/disconnections for $SERVERNAME server."
echo "${cc_red}live ${cc_normal}- Show a live updated log for $SERVERNAME server."
echo "${cc_red}log ${cc_normal}- Show last 25 lines of log for $SERVERNAME server."
echo "${cc_red}log50 ${cc_normal}- Show last 50 lines of log for $SERVERNAME server."
echo "${cc_red}lagmem ${cc_normal}- View lag and memory information."
echo "${cc_red}backupmap ${cc_normal}- Backup maps ${cc_green}$worldlist${cc_normal} to ${cc_green}$BACKUPPATH${cc_normal}."
echo "${cc_red}backupall ${cc_normal}- Backup contents of $MCPATH to ${cc_green}$BACKUPPATH${cc_normal}."

exit 1;
;;
esac
 
exit 0;