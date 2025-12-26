#!/bin/bash

set -euo pipefail

PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:/sbin"
LOG_FILE="/tmp/wifi-toggle.log"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S%z')" "$*" >> "$LOG_FILE"
}

require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        log "This script must run as root to control Wi-Fi power."
        exit 1
    fi
}

get_wifi_device() {
    networksetup -listallhardwareports | awk '
        /^Hardware Port: (Wi-Fi|AirPort)$/ {
            getline
            if ($1 == "Device:") {
                print $2
                exit
            }
        }
    '
}

get_port_name_for_device() {
    local device="$1"
    networksetup -listallhardwareports | awk -v target="$device" '
        /^Hardware Port: / {
            port=$0
            sub(/^Hardware Port: /, "", port)
        }
        /^Device: / {
            dev=$0
            sub(/^Device: /, "", dev)
            if (dev == target) {
                print port
                exit
            }
        }
    '
}

list_active_ethernet_devices() {
    # Enumerate all hardware ports and return device names excluding Wi-Fi/AirPort.
    networksetup -listallhardwareports | awk '
        /^Hardware Port: / {
            port=$0
            sub(/^Hardware Port: /, "", port)
        }
        /^Device: / {
            dev=$0
            sub(/^Device: /, "", dev)
            if (dev != "" && port !~ /^(Wi-Fi|AirPort)$/) {
                print dev
            }
            port=""
        }
    '
}

is_virtual_port() {
    local name="$1"
    case "$name" in
        *Bridge*|*bridge*|*VPN*|*vpn*|*Virtual*|*virtual*|*VMware*|*Parallels*|*vnic*|*VLAN*|*Bluetooth\ PAN*|*Thunderbolt\ Bridge*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

wifi_power_state() {
    local device="$1"
    local port="$2"
    local output=""
    if [[ -n "$device" ]] && output=$(networksetup -getairportpower "$device" 2>/dev/null); then
        :
    elif [[ -n "$port" ]] && output=$(networksetup -getairportpower "$port" 2>/dev/null); then
        :
    else
        log "Unable to read Wi-Fi power state for ${device:-unknown}."
        echo "Unknown"
        return
    fi

    if printf '%s' "$output" | grep -q "On"; then
        echo "On"
    else
        echo "Off"
    fi
}

has_active_physical_ethernet() {
    while IFS= read -r dev; do
        [[ -z "$dev" ]] && continue
        local port_name
        port_name="$(get_port_name_for_device "$dev")"
        [[ -z "$port_name" ]] && continue
        if is_virtual_port "$port_name"; then
            continue
        fi
        if ifconfig "$dev" 2>/dev/null | grep -q "status: active"; then
            log "Detected active Ethernet link on ${port_name} (${dev})."
            return 0
        fi
    done < <(list_active_ethernet_devices)
    return 1
}

toggle_wifi() {
    local desired="$1"
    local device="$2"
    local port="$3"
    case "$desired" in
        on|off)
            if networksetup -setairportpower "$device" "$desired" 2>/dev/null; then
                log "Set Wi-Fi (${device}) power $desired."
                return 0
            elif [[ -n "$port" ]] && networksetup -setairportpower "$port" "$desired" 2>/dev/null; then
                log "Set Wi-Fi (${port}) power $desired."
                return 0
            fi
            log "Failed to change Wi-Fi state to $desired."
            return 1
            ;;
        *)
            log "Invalid Wi-Fi power state requested: $desired"
            return 1
            ;;
    esac
}

main() {
    require_root

    local wifi_device
    wifi_device="$(get_wifi_device || true)"
    if [[ -z "$wifi_device" ]]; then
        log "No Wi-Fi hardware port found; exiting."
        exit 0
    fi

    local wifi_port
    wifi_port="$(get_port_name_for_device "$wifi_device")"
    if [[ -z "$wifi_port" ]]; then
        log "Wi-Fi hardware port name could not be resolved."
    fi

    local wifi_state
    wifi_state="$(wifi_power_state "$wifi_device" "$wifi_port")"
    if [[ "$wifi_state" == "Unknown" ]]; then
        exit 1
    fi

    if has_active_physical_ethernet; then
        if [[ "$wifi_state" == "On" ]]; then
            toggle_wifi off "$wifi_device" "$wifi_port"
        else
            log "Wi-Fi already off; no action taken."
        fi
    else
        if [[ "$wifi_state" == "Off" ]]; then
            toggle_wifi on "$wifi_device" "$wifi_port"
        else
            log "Wi-Fi already on; no action taken."
        fi
    fi
}

main "$@"
