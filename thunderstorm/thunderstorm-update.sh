#!/bin/bash
#
# THOR Thunderstorm Installer
# Florian Roth
#
# Script parameters
# full: upgrade the binaries and signatures (default: signatures only)

VERSION="0.1.0"

# Program Directory
PROGRAM_DIR="/opt/nextron/thunderstorm"

# Program -------------------------------------------------------------

echo "=============================================================="
echo "    ________                __            __                "
echo "   /_  __/ /  __ _____  ___/ /__ _______ / /____  ______ _  "
echo "    / / / _ \/ // / _ \/ _  / -_) __(_-</ __/ _ \/ __/  ' \ "
echo "   /_/ /_//_/\_,_/_//_/\_,_/\__/_/ /___/\__/\___/_/ /_/_/_/ "
echo "   v$VERSION"
echo " "
echo "   THOR Thunderstorm Updater"
echo "   Florian Roth, September 2020"
echo "=============================================================="

# Root check
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

# Change working directory to THOR default program path
cd $PROGRAM_DIR || { echo "Cannot find THOR Thunderstorm program directory $PROGRAM_DIR. It seems as if Thunderstorm isn't installed."; exit 1; }

# Uninstaller
if [ "$1" == "full" ]; then
    echo "Trying to stop the Thunderstorm service ..."
    systemctl stop thor-thunderstorm || { echo "Cannot stop the Thunderstorm service"; exit 1; }
    echo "Upgrading THOR and signatures ..."
    ./thor-util upgrade --license-path /etc/thunderstorm
    echo "Restarting Thunderstorm service ..."
    systemctl start thor-thunderstorm || { echo "Cannot start the Thunderstorm service. Check the log /var/log/thunderstorm/thunderstorm.log for errors or try to start it manually in the terminal with /opt/nextron/thunderstorm/thor-linux-64 --thunderstorm -t /etc/thunderstorm/thunderstorm.yml"; exit 1; }
    echo "Successfully updated THOR and signatures"
    exit 0
else
    echo "Updating signatures ..."
    ./thor-util update --license-path /etc/thunderstorm
    echo "Successfully updated signatures"
    echo "Now restart the Thunderstorm service at the next opportunity with: sudo systemctl restart thor-thunderstorm"
fi