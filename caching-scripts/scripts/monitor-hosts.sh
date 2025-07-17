#!/usr/bin/env bash


# Monitor hosts file for .local domain changes
# This script can be used to track hosts file modifications

HOSTS_FILE="/etc/hosts"
LOG_FILE="/var/log/caching-scripts/hosts-changes.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Function to log changes
log_change() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if hosts file exists
if [ ! -f "$HOSTS_FILE" ]; then
    log_change "ERROR: Hosts file not found at $HOSTS_FILE"
    exit 1
fi

# Get current .local domains
CURRENT_DOMAINS=$(grep "127.0.0.1.*\.local" "$HOSTS_FILE" | awk '{print $2}' | sort)

echo "Current .local domains in hosts file:"
echo "$CURRENT_DOMAINS"

# Log current state
log_change "Hosts file check - $(echo "$CURRENT_DOMAINS" | wc -l) .local domains found"

# Show recent changes from log
if [ -f "$LOG_FILE" ]; then
    echo ""
    echo "Recent hosts file changes:"
    tail -10 "$LOG_FILE"
fi
