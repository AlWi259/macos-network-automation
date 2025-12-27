#!/bin/bash
# Status checker for Wi-Fi auto-toggle

set -euo pipefail
IFS=$'\n\t'

PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:/sbin"
export PATH

SCRIPT_DST="/usr/local/sbin/wifi-toggle.sh"
PLIST_DST="/Library/LaunchDaemons/com.user.wifitoggle.plist"
LOG_FILE="/tmp/wifi-toggle.log"

GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Print usage help
usage() {
    cat <<'EOF'
Usage: ./check-status.sh

Shows daemon status, file presence/permissions, and recent log entries.
EOF
}

# Print a single status line
status_line() {
    local label="$1" value="$2" color="$3"
    printf '%b%-25s%b %s\n' "$color" "$label" "$NC" "$value"
}

# Check if the LaunchDaemon is loaded
daemon_loaded() {
    launchctl print system/com.user.wifitoggle >/dev/null 2>&1
}

# Return file permission string or "missing"
perm_string() {
    if [[ -e "$1" ]]; then
        stat -f "%Sp %Su:%Sg" "$1"
    else
        echo "missing"
    fi
}

# Main entry point
main() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        usage
        exit 0
    fi

    if daemon_loaded; then
        status_line "Daemon" "Loaded" "$GREEN"
    else
        status_line "Daemon" "Not loaded" "$RED"
    fi

    status_line "Script" "$(perm_string "$SCRIPT_DST")" "$YELLOW"
    status_line "Plist" "$(perm_string "$PLIST_DST")" "$YELLOW"

    printf '\nLast 5 log lines (%s):\n' "$LOG_FILE"
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 5 "$LOG_FILE"
    else
        echo "No log file found."
    fi
}

main "$@"
