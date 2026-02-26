#!/usr/bin/env bash

# Declare variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE}")" && pwd)"
LOGFILE="${SCRIPT_DIR}/inputlog.txt"
EVENT_DIR="/dev/input"

# Cleanup (important asf)
cleanup() {
    echo "Shutting down..."
    kill $(jobs -p) 2>/dev/null
    exit 0
}

# Catch ctrl-c
trap cleanup SIGINT

# Check root
if [[ $EUID -ne 0 ]]; then
    echo "This script needs root to read input devices and solve dependencies."
    echo "Try sudo."
    exit 1
fi

# Check dependencies
if ! command -v evtest &> /dev/null; then
    echo "evtest not found. Installing..."
    
    installed=false
    
    # Try apt (Debian/Ubuntu)
    if command -v apt &> /dev/null; then
        echo "Trying apt..."
        sudo apt update && sudo apt install -y evtest && installed=true
    fi
    
    # Try apt-get (older Debian/Ubuntu)
    if [[ "$installed" == false ]] && command -v apt-get &> /dev/null; then
        echo "Trying apt-get..."
        sudo apt-get update && sudo apt-get install -y evtest && installed=true
    fi
    
    # Try yum (RHEL/CentOS/Fedora)
    if [[ "$installed" == false ]] && command -v yum &> /dev/null; then
        echo "Trying yum..."
        sudo yum install -y evtest && installed=true
    fi
    
    # Try dnf (Fedora)
    if [[ "$installed" == false ]] && command -v dnf &> /dev/null; then
        echo "Trying dnf..."
        sudo dnf install -y evtest && installed=true
    fi
    
    # Try pacman (Arch)
    if [[ "$installed" == false ]] && command -v pacman &> /dev/null; then
        echo "Trying pacman..."
        sudo pacman -S --noconfirm evtest && installed=true
    fi
    
    # Try brew (macOS/Bluefin)
    if [[ "$installed" == false ]] && command -v brew &> /dev/null; then
        echo "Trying brew..."
        brew install evtest && installed=true
    fi
    
    if [[ "$installed" == false ]]; then
        echo "Error: Failed to install evtest with any package manager"
        exit 1
    fi
fi

# Generate log file
touch "$LOGFILE"
chmod 666 "$LOGFILE"
echo "----- Capture Started -----" >> "$LOGFILE"
echo "[DATE|TIME] [DEVICE] INPUT CODE (KEY) (STATE)" >> "$LOGFILE"

# Handler function
handle_event() {
    local event_file="$1"
    while IFS= read -r line; do
        local key value state
        key=$(echo "$line" | grep -oP 'code \K[^,]+')
        value=$(echo "$line" | grep -oP 'value \K[^ ]+')
        
        case "$value" in
            0) state="RELEASED" ;;
            1) state="PRESSED" ;;
            2) state="HELD" ;;
            *) state="UNKNOWN" ;;
        esac
        
        if [[ -n "$key" ]]; then
                echo "[$(date '+%m/%d/%Y|%H:%M:%S.%2N')] [$event_file] $key ($state)" >> "$LOGFILE"
        fi
    done
}

# Capture and save inputs from all event files
for event_file in "$EVENT_DIR"/event*; do
    if [[ -e "$event_file" ]]; then
        echo "Monitoring $event_file..."
        evtest "$event_file" \
            | grep --line-buffered ", type 1 " \
            | handle_event "$event_file" &
    fi
done

# Keep the script running
wait