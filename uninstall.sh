#!/bin/bash
# Uninstallation script for Network Toggle Automation
# Usage: sudo ./uninstall.sh [--verbose|-v] [--help|-h]

set -euo pipefail
IFS=$'\n\t'

PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:/sbin"
export PATH

SCRIPT_DST="/usr/local/sbin/wifi-toggle.sh"
PLIST_DST="/Library/LaunchDaemons/com.user.wifitoggle.plist"
MENU_APP_DST="/Applications/NetworkToggle.app"
UNINSTALL_LOG="/tmp/wifi-toggle-uninstall.log"

GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[1;33m"; NC="\033[0m"
CHECK="${GREEN}✔${NC}"; WARN="${YELLOW}!${NC}"; FAIL="${RED}✖${NC}"

VERBOSE=false

usage() {
    cat <<'EOF'
Usage: sudo ./uninstall.sh [--verbose|-v] [--help|-h]
Safely unloads the LaunchDaemon and removes installed files.
EOF
}

log_message() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$*" >> "$UNINSTALL_LOG"
    if [[ "$VERBOSE" == "true" ]]; then
        printf '%s\n' "$*"
    fi
}

info() { printf '%s %s\n' "$YELLOW" "$1$NC"; }
success() { printf '%s %s\n' "$CHECK" "$1"; }
warning() { printf '%s %s\n' "$WARN" "$1"; }
error() { printf '%s %s\n' "$FAIL" "$1" >&2; }

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        error "Run as root (sudo)."
        exit 1
    fi
}

prompt_yes_no() {
    local prompt="$1" default="${2:-Y}" reply suffix="[Y/n]"
    [[ "$default" == "N" ]] && suffix="[y/N]"
    printf "%s %s " "$prompt" "$suffix"
    read -r reply || true
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[Yy]$ ]]
}

daemon_loaded() { launchctl print system/com.user.wifitoggle >/dev/null 2>&1; }

unload_daemon() {
    launchctl bootout system "$PLIST_DST" >/dev/null 2>&1 || true
    log_message "Daemon unloaded."
}

remove_files() {
    rm -f "$PLIST_DST"
    rm -f "$SCRIPT_DST"
    log_message "Removed plist and script."
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v) VERBOSE=true; shift ;;
            --help|-h) usage; exit 0 ;;
            *) error "Unknown argument: $1"; exit 1 ;;
        esac
    done

    require_root

    if ! prompt_yes_no "Uninstall Network Toggle automation?" "N"; then
        info "Cancelled."
        exit 0
    fi

    if daemon_loaded; then
        unload_daemon
        success "LaunchDaemon unloaded."
    else
        warning "Daemon not loaded."
    fi

    remove_files
    success "Removed installed files."

    if prompt_yes_no "Remove /tmp/wifi-toggle.log?" "N"; then
        rm -f /tmp/wifi-toggle.log
        log_message "Removed log file."
    fi

    if prompt_yes_no "Remove menu bar app at /Applications/NetworkToggle.app if present?" "N"; then
        rm -rf "$MENU_APP_DST" 2>/dev/null || true
        log_message "Removed menu app."
    fi

    success "Uninstall complete."
    info "Log: $UNINSTALL_LOG"
    exit 0
}

main "$@"
