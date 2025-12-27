#!/bin/bash
# Installation script for Network Toggle Automation
# Usage: sudo ./install.sh [--verbose|-v] [--help|-h]
set -euo pipefail
IFS=$'\n\t'; PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:/sbin"; export PATH

# Resolve the repo root for relative paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_SRC="${SCRIPT_DIR}/wifi-toggle.sh"
PLIST_SRC="${SCRIPT_DIR}/com.user.wifitoggle.plist"
SCRIPT_DST="/usr/local/sbin/wifi-toggle.sh"
PLIST_DST="/Library/LaunchDaemons/com.user.wifitoggle.plist"
MENU_APP_SRC="${SCRIPT_DIR}/MenuBarApp/NetworkToggle.app"
MENU_APP_DST="/Applications/NetworkToggle.app"
INSTALL_LOG="/tmp/wifi-toggle-install.log"
GREEN="\033[0;32m"; RED="\033[0;31m"; YELLOW="\033[1;33m"; BLUE="\033[0;34m"; NC="\033[0m"
CHECK="${GREEN}✔${NC}"; WARN="${YELLOW}!${NC}"; FAIL="${RED}✖${NC}"

VERBOSE=false; ROLLBACK_ITEMS=()

# Print usage help
usage() {
    cat <<'EOF'
Usage: sudo ./install.sh [--verbose|-v] [--help|-h]
Installs wifi-toggle.sh, the LaunchDaemon, and optionally the menu bar app.
EOF
}

# Write a log line to the install log
log_message() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$*" >> "$INSTALL_LOG"
    [[ "$VERBOSE" == "true" ]] && printf '%s\n' "$*"
}

# Print a colored status line
status() {
    case "$1" in
        info) printf '%b %s%s\n' "$BLUE" "$2" "$NC" ;;
        ok) printf '%b %s\n' "$CHECK" "$2" ;;
        warn) printf '%b %s\n' "$WARN" "$2" ;;
        err) printf '%b %s\n' "$FAIL" "$2" >&2 ;;
    esac
}

# Remove partial files if installation fails
cleanup_on_error() {
    if [[ "${#ROLLBACK_ITEMS[@]}" -gt 0 ]]; then
        status warn "Rolling back partial install..."
        for item in "${ROLLBACK_ITEMS[@]}"; do rm -rf "$item" 2>/dev/null || true; done
    fi
}
trap 'status err "Installation failed."; cleanup_on_error; exit 1' ERR

# Ensure script runs as root
require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then status err "Run as root (sudo)."; exit 1; fi
}

# Ask a yes/no question
prompt_yes_no() {
    local prompt="$1" default="${2:-Y}" reply suffix="[Y/n]"
    [[ "$default" == "N" ]] && suffix="[y/N]"
    printf "%s %s " "$prompt" "$suffix"
    read -r reply || true
    reply="${reply:-$default}"
    [[ "$reply" =~ ^[Yy]$ ]]
}

# Ensure a command exists
check_command() { command -v "$1" >/dev/null 2>&1 || { status err "Missing $1"; exit 1; }; }
# Ensure a file exists
verify_file() { [[ -f "$1" ]] || { status err "Missing file: $1"; exit 1; }; }

# Verify macOS version is supported
check_macos_version() {
    local ver major
    ver="$(sw_vers -productVersion 2>/dev/null || true)"; major="${ver%%.*}"
    if [[ -z "$major" || "$major" -lt 13 ]]; then status err "macOS 13+ required (found $ver)"; exit 1; fi
}

# Check if the LaunchDaemon is loaded
daemon_loaded() { launchctl print system/com.user.wifitoggle >/dev/null 2>&1; }

# Create required directories with permissions
ensure_dirs() {
    if [[ ! -d "/usr/local/sbin" ]]; then
        if prompt_yes_no "Create /usr/local/sbin?" "Y"; then
            mkdir -p /usr/local/sbin && chmod 755 /usr/local/sbin
            log_message "Created /usr/local/sbin"
        else
            status err "Cannot continue without /usr/local/sbin."
            exit 1
        fi
    fi
}

# Copy script and plist to system locations
copy_files() {
    /usr/bin/install -m 755 "$SCRIPT_SRC" "$SCRIPT_DST"
    /usr/bin/install -m 644 "$PLIST_SRC" "$PLIST_DST"
    chown root:wheel "$SCRIPT_DST" "$PLIST_DST"
    ROLLBACK_ITEMS+=("$SCRIPT_DST" "$PLIST_DST")
    status ok "Installed script and plist."
    log_message "Installed to $SCRIPT_DST and $PLIST_DST"
}

# Bootstrap and kickstart the LaunchDaemon
load_daemon() {
    launchctl bootout system "$PLIST_DST" >/dev/null 2>&1 || true
    launchctl bootstrap system "$PLIST_DST"
    launchctl kickstart -k system/com.user.wifitoggle
    status ok "LaunchDaemon loaded."
    log_message "Daemon bootstrapped."
}

# Validate daemon state and dry-run behavior
verify_install() {
    daemon_loaded || { status err "Daemon failed to load."; exit 1; }
    status ok "Daemon is running."
    if "$SCRIPT_DST" --dry-run >/dev/null 2>&1; then
        status ok "Dry-run succeeded."
    else
        status warn "Dry-run failed; check /tmp/wifi-toggle.log."
    fi
}

# Optionally install the menu bar app to /Applications
maybe_install_menu_app() {
    if [[ -d "$MENU_APP_SRC" ]] && prompt_yes_no "Install menu bar app to /Applications?" "N"; then
        cp -R "$MENU_APP_SRC" "$MENU_APP_DST"
        ROLLBACK_ITEMS+=("$MENU_APP_DST")
        status ok "Menu bar app installed to /Applications."
        log_message "Menu app copied."
    fi
}

# Parse CLI arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --verbose|-v) VERBOSE=true; shift ;;
            --help|-h) usage; exit 0 ;;
            *) status err "Unknown argument: $1"; exit 1 ;;
        esac
    done
}

# Main entry point
main() {
    parse_args "$@"
    require_root
    check_command networksetup; check_command launchctl; check_command install
    check_macos_version
    verify_file "$SCRIPT_SRC"; verify_file "$PLIST_SRC"
    ensure_dirs

    if daemon_loaded; then
        status warn "Daemon already loaded."
        prompt_yes_no "Reinstall and reload?" "N" || { status info "No changes made."; exit 2; }
    fi

    copy_files
    load_daemon
    maybe_install_menu_app
    verify_install

    status ok "Installation complete."
    status info "Log: $INSTALL_LOG"
    exit 0
}

main "$@"
