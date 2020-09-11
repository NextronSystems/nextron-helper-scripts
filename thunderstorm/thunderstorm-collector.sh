#!/bin/bash
#
# THOR Thunderstorm Installer
# Florian Roth

VERSION="0.1.0"

# Settings ------------------------------------------------------------

# Log
LOGFILE="/var/log/thunderstorm.log"
LOG_TO_FILE=1
LOG_TO_SYSLOG=0 # Log to syslog is set to 'off' by default
LOG_TO_CMDLINE=1

# Thunderstorm Server
THUNDERSTORM_SERVER="ygdrasil.nextron"
USE_SSL=0
ASYNC_MODE=1

# Target selection 
declare -a SCAN_FOLDERS=('/var' '/home');  # folders to scan 
MAX_AGE=14
MAX_FILE_SIZE=2000  # max file size to check in kilobyte, default 2 MB

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
    curl_avail=$(command -v curl)
    if [[ -z $curl_avail ]]; then 
        log error "The 'curl' command can't be found but is needed"
        exit 1
    fi
}

# Program -------------------------------------------------------------

echo "=============================================================="
echo "    ________                __            __                "
echo "   /_  __/ /  __ _____  ___/ /__ _______ / /____  ______ _  "
echo "    / / / _ \/ // / _ \/ _  / -_) __(_-</ __/ _ \/ __/  ' \ "
echo "   /_/ /_//_/\_,_/_//_/\_,_/\__/_/ /___/\__/\___/_/ /_/_/_/ "
echo "   v$VERSION"
echo " "
echo "   THOR Thunderstorm Collector for Linux/Unix"
echo "   Florian Roth, September 2020"
echo "=============================================================="

# Root check
if [ "$(id -u)" != "0" ]; then
   log error "This script should be run as root to have access to all files on disk" 1>&2
   exit 1
fi

echo "Writing log file to $LOGFILE ..."

log info "Started Thunderstorm Collector - Version $VERSION"
log info "Transmitting samples to $THUNDERSTORM_SERVER"
log info "Processing folders ${SCAN_FOLDERS[*]}"
log info "Only check files created / modified within $MAX_AGE days"
log info "Only process files smaller $MAX_FILE_SIZE KB"

# Check requirements
check_req

# Some presets
api_endpoint="check"
if [[ $ASYNC_MODE -eq 1 ]]; then
    api_endpoint="checkAsync"
fi
scheme="http"
if [[ $USE_SSL -eq 1 ]]; then
    scheme="https"
fi

# Loop over filesystem
for scandir in "${SCAN_FOLDERS[@]}";
do
    find "$scandir" -type f  -mtime -$MAX_AGE 2> /dev/null | while read -r file_path
    do
        if [ -f "${file_path}" ]; then
            # Check Size
            filesize=$(du -k "$file_path" | cut -f1)
            if [ "${filesize}" -gt $MAX_FILE_SIZE ]; then
                continue
            fi
            log debug "Submitting ${file_path} ..."
            # Submit sample
            result=$(curl -s -X POST \
                     "$scheme://$THUNDERSTORM_SERVER:8080/api/$api_endpoint" \
                     -F "file=@$file_path")
            # If not 'id' in result
            error="reason"
            if [ "${result/$error}" != "$result" ]; then
                log error "$result"
            fi
        fi
    done 
done
exit 0