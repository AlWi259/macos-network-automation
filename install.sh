#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:/sbin"
export PATH

SCRIPT_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/wifi-toggle.sh"
PLIST_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/com.user.wifitoggle.plist"
SCRIPT_DST="/usr/local/sbin/wifi-toggle.sh"
PLIST_DST="/Library/LaunchDaemons/com.user.wifitoggle.plist"

usage() {
    cat <<'EOF'
Usage: sudo ./install.sh [install|reload|uninstall]

install   Copy script and plist, then load the LaunchDaemon
reload    Reload the LaunchDaemon after updating files
uninstall Remove the LaunchDaemon and installed files
EOF
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        echo "ERROR: Run this script as root (sudo)." >&2
        exit 1
    fi
}

install_files() {
    /usr/bin/install -d -m 755 /usr/local/sbin
    /usr/bin/install -m 755 "$SCRIPT_SRC" "$SCRIPT_DST"
    /usr/bin/install -m 644 "$PLIST_SRC" "$PLIST_DST"
}

load_daemon() {
    /bin/launchctl bootout system "$PLIST_DST" 2>/dev/null || true
    /bin/launchctl bootstrap system "$PLIST_DST"
    /bin/launchctl kickstart -k system/com.user.wifitoggle
}

unload_daemon() {
    /bin/launchctl bootout system "$PLIST_DST" 2>/dev/null || true
}

uninstall_files() {
    /bin/rm -f "$PLIST_DST" "$SCRIPT_DST"
}

main() {
    require_root
    local action="${1:-install}"
    case "$action" in
        install)
            install_files
            load_daemon
            echo "Installed and started com.user.wifitoggle."
            ;;
        reload)
            install_files
            load_daemon
            echo "Reloaded com.user.wifitoggle."
            ;;
        uninstall)
            unload_daemon
            uninstall_files
            echo "Uninstalled com.user.wifitoggle."
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
