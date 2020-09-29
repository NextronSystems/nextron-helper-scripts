#!/bin/bash
#
# THOR Thunderstorm Installer
# Florian Roth
#
# Script parameters
# uninstall: Uninstall Thunderstorm service
# auto: Don't prompt for a confirmation

VERSION="0.3.0"

# Settings ------------------------------------------------------------
SYSTEM_NAME=$(uname -n | tr -d "\n")
TS_CONDENSED=$(date +%Y%m%d)

# Target Directory
TARGET_DIR="/opt/nextron/thunderstorm"

# Log
LOGFILE="./Thunderstorm_Installer_${SYSTEM_NAME}_${TS_CONDENSED}.log"
LOG_TO_FILE=1
LOG_TO_SYSLOG=0 # Log to syslog is set to 'off' by default
LOG_TO_CMDLINE=1

# Software and License Download
# Nextron Update Servers
declare -a UPDATE_SERVERS=('update1.nextron-systems.com' 'update2.nextron-systems.com');

# Configs
# Service Deamon
read -r -d '' SERVICE_CONFIG << EOM
[Unit]
Description=THOR Thunderstorm Server

[Service]
AmbientCapabilities=CAP_NET_BIND_SERVICE
Type=simple
ExecStart=/opt/nextron/thunderstorm/thor-linux-64 --thunderstorm -t /etc/thunderstorm/thunderstorm.yml
WorkingDirectory=/opt/nextron/thunderstorm
User=thunderstorm
Restart=always
StandardOutput=null

[Install]
WantedBy=multi-user.target
EOM

# Config File in Etc
read -r -d '' THUNDERSTORM_CONFIG << EOM
# License path 
license-path: /etc/thunderstorm
# Write all outputs to the following directory
logfile: /var/log/thunderstorm/thunderstorm.log
appendlog: True
# Listen on all possible network interfaces
server-host: 0.0.0.0
server-port: 8080
# Pure YARA scanning
pure-yara: False

# SSL/TLS
# SSL/TLS Server Certificate
#server-cert: /path/to/file
# SSL/TLS Server Certificate Private Key
#server-key: /path/to/file

# File Submissions
# Directory to which the samples get stored in asynchronous mode
server-upload-dir: /tmp/thunderstorm
# Permanently store the submitted samples (valied values: none/all/malicious)
server-store-samples: none

# Tuning
# Server Result Cache 
# This is the number of cached results from asynchronous submission
# available for remote queries (default: 10000)
#server-result-cache-size: 10000

# for all other THOR command line flags see:
# https://github.com/NextronSystems/nextron-helper-scripts/tree/master/thor-help
EOM

# Debug
DEBUG=1

# Code ----------------------------------------------------------------

function timestamp {
  date +%F_%T
}

function log {
    local type="$1"
    local message="$2"
    local ts
    ts=$(timestamp)

    # Only report debug messages if mode is enabled
    if [ "$type" == "debug" ] && [ $DEBUG -ne 1 ]; then
        return 0
    fi

    # Exclude certain strings (false positives)
    for ex_string in "${EXCLUDE_STRINGS[@]}";
    do
        # echo "Checking if $ex_string is in $message"
        if [ "${message/$ex_string}" != "$message" ]; then
            return 0
        fi
    done

    # Remove line breaks
    message=$(echo "$message" | tr -d '\r' | tr '\n' ' ') 

    # Remove prefix (e.g. [+])
    if [[ "${message:0:1}" == "[" ]]; then
        message_cleaned="${message:4:${#message}}"
    else
        message_cleaned="$message"
    fi

    # Log to file
    if [[ $LOG_TO_FILE -eq 1 ]]; then
        echo "$ts $type $message_cleaned" >> "$LOGFILE"
    fi
    # Log to syslog
    if [[ $LOG_TO_SYSLOG -eq 1 ]]; then
        logger -p "$SYSLOG_FACILITY.$type" "$(basename "$0"): $message_cleaned"
    fi
    # Log to command line
    if [[ $LOG_TO_CMDLINE -eq 1 ]]; then
        echo "$message" >&2
    fi
}

function check_req 
{
    log info "Checking the required utilities ..."
    wget_avail=$(command -v wget)
    if [[ -z $wget_avail ]]; then 
        log error "The 'wget' command can't be found but is needed (install with: sudo apt install wget / sudo yum install wget)"
        exit 1
    fi
    zip_avail=$(command -v unzip)
    if [[ -z $zip_avail ]]; then 
        log error "The 'unzip' command can't be found but is needed (install with: sudo apt install unzip / sudo yum install unzip)"
        exit 1
    fi
    md5sum_avail=$(command -v md5sum)
    if [[ -z $md5sum_avail ]]; then 
        log error "The 'md5sum' command can't be found but is needed"
        exit 1
    fi
    log debug "All required utilities found."
}

function get_lic_hash
{
    local num_lics=0
    local md5="" 
    local lic_files
    lic_files=$(ls ./*.lic)
    for lic_file in $lic_files; do
        ((num_lics=num_lics+1))
        log info "Found license file $lic_file"
        md5=$(md5sum "$lic_file" 2> /dev/null | cut -f1 -d' ')
    done
    if [ "$num_lics" -gt 1 ]; then 
        log warning "More than one license files (*.lic) found in the current directory. Will choose the last one, which could be the wrong one. Better remove all invalid license files."
    fi
    echo "$md5"
}

function download_thor
{
    # License Hash
    local md5="$1"
    # Select one of the update servers
    index=$((RANDOM % 2))
    DOWNLOAD_URL="https://${UPDATE_SERVERS[$index]}/getupdate.php?full=1&lic=$md5&product=thor10-linux&thorupgrader=thunderstorm-installer&techpreview=1"

    # Start Download
    log info "Downloading THOR for Linux x64 ..."
    log debug "URL: $DOWNLOAD_URL"
    wget -O $TARGET_DIR/thor.zip "$DOWNLOAD_URL"
    return $?
}

function download_update_script
{
    log info "Install thunderstorm-update script ..."
    wget -O /usr/local/sbin/thunderstorm-update https://raw.githubusercontent.com/NextronSystems/nextron-helper-scripts/master/thunderstorm/thunderstorm-update.sh
    chmod +x /usr/local/sbin/thunderstorm-update
}

# Program -------------------------------------------------------------

echo "=============================================================="
echo "    ________                __            __                "
echo "   /_  __/ /  __ _____  ___/ /__ _______ / /____  ______ _  "
echo "    / / / _ \/ // / _ \/ _  / -_) __(_-</ __/ _ \/ __/  ' \ "
echo "   /_/ /_//_/\_,_/_//_/\_,_/\__/_/ /___/\__/\___/_/ /_/_/_/ "
echo "   v$VERSION"
echo " "
echo "   THOR Thunderstorm Service Installer"
echo "   Florian Roth, September 2020"
echo "=============================================================="

# Root check
if [ "$(id -u)" != "0" ]; then
   log error "This script must be run as root" 1>&2
   exit 1
fi

# No promopt
automatic=0
if [ "$1" == "auto" ]; then 
    automatic=1
fi

# Uninstaller
if [ "$1" == "uninstall" ]; then
    read -p "Do you really want to remove THOR Thunderstorm and all its config files? " -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]
    then
        log info "Uninstall has been interrupted. No files have been removed."
        exit 0
    fi
    rm -rf /opt/nextron/thunderstorm 
    rm -rf /etc/thunderstorm 
    rm -rf /tmp/thunderstorm
    rm -rf /usr/local/sbin/thunderstorm-update
    systemctl stop thor-thunderstorm
    systemctl disable thor-thunderstorm
    rm -rf /etc/systemd/system/thor-thunderstorm.service
    systemctl daemon-reload
    userdel thunderstorm
    rm -rf /home/thunderstorm
    # keep the logs
    #rm -rf /var/log/thunderstorm
    exit 0
fi

if [[ $automatic -eq 0 ]]; then
    # Info on what is going to happen
    echo 
    echo "The script will make the following changes to your system:"
    echo "  1. Install THOR into /opt/nextron/thunderstorm"
    echo "  2. Drops a base configuration into /etc/thunderstorm"
    echo "  3. Create a log directory /var/log/thunderstorm for log files of the service"
    echo "  4. Create a user named 'thunderstorm' for the new service"
    echo "  5. Create a new service named 'thor-thunderstorm'"
    echo 
    echo "You can uninstall THOR Thunderstorm with './thunderstorm-installer uninstall'"
    echo
    read -p "Are you ready to install THOR Thunderstorm? (y/n)" -n 1 -r
    echo    # (optional) move to a new line
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log info "Thunderstorm installer has been interrupted."
        exit 0
    fi
fi

log info "Started Thunderstorm Installer - version $VERSION"
log info "Writing logfile to ${LOGFILE}"
log info "HOSTNAME: ${SYSTEM_NAME}"

IP_ADDRESS=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | tr '\n' ' ')
OS_RELEASE=$(cat /etc/*release 2> /dev/null | sort -u | tr "\n" ";")
OS_ISSUE=$(cat /etc/issue 2> /dev/null)
OS_KERNEL=$(uname -a)

log info "IP: $IP_ADDRESS"
log info "OS: $OS_RELEASE"
log info "ISSUE: $OS_ISSUE"
log info "KERNEL: $OS_KERNEL"

# Check requirements
check_req

# Read the license
log info "Searching for license file in current folder ..."
lic_hash=$(get_lic_hash)
if [[ "$lic_hash" == "" ]]; then 
    log error "No license file *.lic found in current folder"
    exit 1
fi
log info "Evaluated license hash: $lic_hash"

# Prepare the target directories
if [ ! -d /opt/nextron/thunderstorm ]; then
    log info "Creating new directory '/opt/nextron/thunderstorm' ..."
    mkdir -p /opt/nextron/thunderstorm
else 
    log info "Thunderstorm directory already exists - assuming upgrade - will not overwrite config files"
fi

# New installation 
if [ ! -f /opt/nextron/thunderstorm/config/thor.yml ]; then 
    new_inst=1
fi

# Add a local user
user_present=$(grep thunderstorm /etc/passwd)
if [ -z "$user_present" ]; then
    log info "Creating new user 'thunderstorm' ..."
    useradd --system -M -c "Thunderstorm Service User" thunderstorm
fi 

# Install Update Script
download_update_script

# Download THOR Package
result_download=$(download_thor "$lic_hash")
if [[ "$result_download" -ne "0" ]]; then
    log error "Download of THOR package failed. Maybe it's a proxy or firewall issue? https://stackoverflow.com/questions/11211705/how-to-set-proxy-for-wget"
    exit 1
fi

# Extract the THOR package
log info "Extracting THOR package to $TARGET_DIR ..."
excl_string=""
if [ $new_inst -eq 0 ]; then 
    excl_string="-x config/*"
fi

if unzip -o -q $TARGET_DIR/thor.zip $excl_string -d $TARGET_DIR; then 
    log info "Successfully unzipped THOR package"
else
    log error "Extraction of THOR package failed."
    exit 1
fi

# Create Config file
log info "Creating config files ..."
if [ ! -d /etc/thunderstorm ]; then
    log info "Creating new directory '/etc/thunderstorm' ..."
    mkdir -p /etc/thunderstorm
    # Write config
    echo "$THUNDERSTORM_CONFIG" > /etc/thunderstorm/thunderstorm.yml
else 
    log warning "Thunderstorm config directory /etc/thunderstorm/ already exists. Installer will not overwrite the current config files. If you want to overwrite the files, remove that directory before running the installer."
fi 

# Copy license to config directory
cp ./*.lic /etc/thunderstorm/

# Create some more directories
log info "Creating directory for temporary files (samples, logs) ..."
if [ ! -d /tmp/thunderstorm ]; then
    log info "Creating sample directory (for asynchronous submissions) '/tmp/thunderstorm' ..."
    mkdir -p /tmp/thunderstorm
fi
if [ ! -d /var/log/thunderstorm ]; then
    log info "Creating log directory '/var/log/thunderstorm' ..."
    mkdir -p /var/log/thunderstorm
fi

# Create Service
# Will overwrite the service file in any case since the config is stored in
# /etc/thunderstorm/thunderstorm.yml
log info "Creating systemd service file in /etc/systemd/system/thor-thunderstorm.service ..."
echo "$SERVICE_CONFIG" > /etc/systemd/system/thor-thunderstorm.service

# Change ownership 
chown thunderstorm /opt/nextron/thunderstorm
chown thunderstorm /var/log/thunderstorm
chown thunderstorm /tmp/thunderstorm

# Deamon Reload and Service Start
log info "Enabling the Thunderstorm service ..."
systemctl daemon-reload
systemctl enable thor-thunderstorm
systemctl start thor-thunderstorm

# Exit
echo "==============================================================="
log info "Finished THOR Thunderstorm Service Installer"
echo 
echo "Created directories and files:"
echo "New service name: thor-thunderstorm (use as e.g. systemctl stop thor-thunderstorm)"
echo "Config:           /etc/thunderstorm/thunderstorm.yml"
echo "Binaries & Sigs:  /opt/nextron/thunderstorm"
echo "Logs:             /var/log/thunderstorm (change that in config)"
echo "Sample Files:     /tmp/thunderstorm (change that in config)"
echo "Documentation:    /opt/nextron/thunderstorm/docs/THOR_Manual.pdf"
echo
echo "Uninstall:       ./thunderstorm-installer uninstall"
echo 
echo DEBUGGING:
echo "In case of a problem: "
echo "  1. check the log file with: tail /var/log/thunderstorm/thunderstorm.log"
echo "  2. try to run the service manually using"
echo "     /opt/nextron/thunderstorm/thor-linux-64 --thunderstorm -t /etc/thunderstorm/thunderstorm.yml"
echo 
echo "Can you hear the rolling thunder?"
echo 
echo "Well, the service should already be up and running."
echo "Within 20 seconds the web interface will be available on http://0.0.0.0:8080"
echo "(and all other available interfaces; you can change that in /etc/thunderstorm/thunderstorm.yml)"
exit 0
