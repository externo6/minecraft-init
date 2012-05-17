#!/bin/bash
# /etc/init.d/minecraft
# version 2012-05-16 (YYYY-MM-DD)
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
 
 HTTPCONSOLE_URL="http://127.0.0.1:8765"
 
function console_command
{
    w3m -dump_source $HTTPCONSOLE_URL/console?command=${*// /%20}
}

 
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
 
## Checks for the minecraft servers screen session. (returns true if it exists)
 
 is_running(){
    if ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
    then
        return 0
    fi
    return 1
}
 
## Start the server
 
mc_start() {
    cd $MCPATH
    as_user "cd $MCPATH && screen -dmS minecraft $INVOCATION"
    #
    # Waiting for the server to start
    #
    seconds=0
    until ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
    do
        sleep 1 
        seconds=$seconds+1
        if [[ $seconds -eq 5 ]]
        then
            echo "Still not running, waiting a while longer..."
        fi
        if [[ $seconds -ge 25 ]]
        then
            echo "Failed to start, aborting."
            exit 1
        fi
    done    
    echo "$SERVERNAME is running."
 
}
 
## Stop the server
 
mc_stop() {
    console_command "say If you are in a arena, do /ma leave NOW!"
	echo "Saving worlds..."
	console_command "save-all"
	sleep 6
    echo "Force ending each arena..."
    console_command "ma force end arena"
    console_command "ma force end biolab"
    console_command "ma force end hotel"
    sleep 3
    console_command "say See you later!"
    sleep 1
	echo "Stopping server..."
	console_command "stop"
	sleep 0.5
	#
	# Waiting for the server to shut down
	#
	seconds=0
	while ps ax | grep -v grep | grep -v -i SCREEN | grep $SERVICE > /dev/null
	do
		sleep 1 
		seconds=$seconds+1
		if [[ $seconds -eq 5 ]]
		then
			echo "Still not shut down, waiting a while longer..."
		fi
		if [[ $seconds -ge 25 ]]
		then
			#logger -t minecraft-init "Failed to shut down server, aborting."
			echo "Failed to shut down, aborting."
			exit 1
		fi
	done	
	echo "$SERVERNAME is now shut down."
}
  
## Set the server read-only, save the map, and have Linux sync filesystem buffers to disk
 
mc_saveoff() {
  	if is_running
	then
		echo "$SERVERNAME is running... suspending saves"
		console_command "save-off"
		console_command "save-all"
		sync
		sleep 10
	else
		echo "$SERVERNAME was not running. Not suspending saves."
	fi
  
  
}
 
## Set the server read-write
 
mc_saveon() {
	if is_running
	then
		echo "$SERVERNAME is running... Re-enabling saves"
		console_command "save-on"
	else
		echo "$SERVERNAME was not running. Not resuming saves."
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
	if is_running
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
	if is_running
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
        console_command "lagmem"
        echo
        echo " - Active Connections : "
        netstat -tna | grep -E "Proto|25565"
        echo
        echo " - Online Players : "
        console_command "list"
	else
		echo " * $SERVERNAME is not running."
	fi
  
}

## Access console
 
mc_console() {
	if is_running
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
#           We shall skip this information. We are pros.
#           clear
#           echo "${cc_red}STOP AND READ"
#           echo
#           echo "Also bug Luke to get this finished."
#           echo
#           echo "${cc_normal}PLEASE! ${cc_red}DEATTACH from the screen ${cc_normal}after you have finished!"
#           echo
#           echo "${cc_green}Do this by Pressing${cc_red} Ctrl-A then Ctrl-D ${cc_normal}"
#           echo
#           echo "or just close the window..."
#           sleep 3
#           echo
#           echo
#           echo
            screen -x MinecraftConsole
            exit
        fi
	else
		echo " * $SERVERNAME is not running."
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

## These are the parameters passed to the script
 
case "$1" in
  start)
        if is_running; then
            echo "Server already running."
        else
            mc_start
            mc_consolestart
        fi
;;
  stop)
        if is_running; then
            console_command "say SERVER SHUTTING DOWN IN 10 SECONDS."
            mc_stop
            mc_consolestop
        else
            echo "Server not running."
        fi
;;
  restart)
        if is_running; then
            console_command "say SERVER RESTARTING IN 10 SECONDS."
            mc_stop
            mc_start
            mc_consolerestart
        else
            echo "Server not running."
        fi
;;
  backupmap)
        console_command "say Starting multiworld backup..."
        mc_saveoff
        mc_backupmap
        mc_saveon
        console_command "say Backup complete!"
;;
  backupall)
        console_command "say Starting full server backup..."
        mc_saveoff
        mc_backupall
        mc_saveon
        console_command "say Backup complete!"
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
        console_command "list"
;;
  lagmem)
        console_command "lagmem"
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