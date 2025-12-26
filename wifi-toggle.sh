#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Version info
VERSION="1.2.0"

# Security: restrict PATH to built-in locations
PATH="/usr/sbin:/usr/bin:/bin:/usr/local/bin:/sbin"
export PATH

# Absolute command paths
NET_SETUP="/usr/sbin/networksetup"
IFCONFIG="/sbin/ifconfig"
GREP="/usr/bin/grep"
DATE="/bin/date"

# Logging
LOG_FILE="/tmp/wifi-toggle.log"

# Runtime flags
DRY_RUN=false
VERBOSE=false

# Hardware cache
wifi_device=""
wifi_port_name=""
hardware_devices=()
hardware_ports=()

# Reserved for future cleanup logic
cleanup() {
    :
}
trap cleanup EXIT

# Show usage help
usage() {
    cat <<'EOF'
Usage: wifi-toggle.sh [--dry-run] [--verbose|-v] [--help]

Automatically disables Wi-Fi when a wired Ethernet link is active and re-enables Wi-Fi when Ethernet is inactive.

Options:
  --dry-run       Show intended actions without changing Wi-Fi power
  --verbose, -v   Print debug output to stdout in addition to the log file
  --help, -h      Show this help text
EOF
}

# Write to the log file
log() {
    printf '%s wifi-toggle: %s\n' "$("$DATE" '+%Y-%m-%d %H:%M:%S%z')" "$*" >> "$LOG_FILE"
}

# Log and optionally echo when verbose
log_verbose() {
    log "$@"
    if [[ "$VERBOSE" == "true" ]]; then
        printf '%s\n' "$*"
    fi
}

# Log an error and exit
fail() {
    log "ERROR: $*"
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

# Ensure the script is running as root
require_root() {
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        fail "Run as root to manage Wi-Fi power."
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            \#*)
                shift
                ;;
            *)
                fail "Unknown argument: $1"
                ;;
        esac
    done
}

# Load hardware ports once and cache device/port pairs
load_hardware_ports() {
    local hw_output
    if ! hw_output=$("$NET_SETUP" -listallhardwareports 2>/dev/null); then
        fail "Unable to list hardware ports."
    fi

    local line="" current_port="" current_dev=""
    while IFS= read -r line; do
        case "$line" in
            "Hardware Port:"*)
                current_port=${line#Hardware Port: }
                ;;
            "Device:"*)
                current_dev=${line#Device: }
                if [[ -n "$current_port" && -n "$current_dev" ]]; then
                    hardware_ports+=("$current_port")
                    hardware_devices+=("$current_dev")
                    if [[ -z "$wifi_device" && "$current_port" =~ ^(Wi-Fi|AirPort)$ ]]; then
                        wifi_device="$current_dev"
                        wifi_port_name="$current_port"
                    fi
                fi
                current_port=""
                current_dev=""
                ;;
            *)
                ;;
        esac
    done <<< "$hw_output"
}

# Get port name for a given BSD device
port_name_for_device() {
    local target="$1" i
    for i in "${!hardware_devices[@]}"; do
        if [[ "${hardware_devices[$i]}" == "$target" ]]; then
            printf '%s' "${hardware_ports[$i]}"
            return 0
        fi
    done
    return 1
}

# Determine Wi-Fi power state (On/Off/Unknown) preferring device first
wifi_power_state() {
    local output=""
    if [[ -n "$wifi_device" ]]; then
        output=$("$NET_SETUP" -getairportpower "$wifi_device" 2>/dev/null || true)
    fi
    if [[ -z "$output" && -n "$wifi_port_name" ]]; then
        output=$("$NET_SETUP" -getairportpower "$wifi_port_name" 2>/dev/null || true)
    fi

    log_verbose "Wi-Fi power query (device=${wifi_device:-none} port=${wifi_port_name:-none}): ${output:-<empty>}"

    if [[ -z "$output" ]]; then
        log "Unable to read Wi-Fi power state."
        printf 'Unknown'
        return 0
    fi

    local lower
    lower=$(printf '%s' "$output" | tr '[:upper:]' '[:lower:]')

    case "$lower" in
        *on*|*ein*)
            printf 'On'
            ;;
        *off*|*aus*)
            printf 'Off'
            ;;
        *)
            printf 'Unknown'
            ;;
    esac
}

# Detect virtual or non-physical ports
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

# Return success if any physical Ethernet interface is active
has_active_physical_ethernet() {
    local dev="" port_name=""
    for dev in "${hardware_devices[@]}"; do
        port_name="$(port_name_for_device "$dev" || true)"
        [[ -z "$port_name" ]] && continue
        if [[ "$port_name" =~ ^(Wi-Fi|AirPort)$ ]]; then
            continue
        fi
        if is_virtual_port "$port_name"; then
            continue
        fi
        if "$IFCONFIG" "$dev" 2>/dev/null | "$GREP" -q "status: active"; then
            log_verbose "Active Ethernet detected on ${port_name} (${dev})."
            return 0
        fi
    done
    return 1
}

# Set Wi-Fi power to on/off respecting dry-run, prefer device
set_wifi_power() {
    local desired="$1"
    if [[ "$desired" != "on" && "$desired" != "off" ]]; then
        fail "Invalid Wi-Fi power request: $desired"
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_verbose "Dry-run: would set Wi-Fi power $desired."
        return 0
    fi

    local output=""

    if [[ -n "$wifi_device" ]] && output=$("$NET_SETUP" -setairportpower "$wifi_device" "$desired" 2>/dev/null); then
        log "Wi-Fi power set to $desired using ${wifi_device}."
        return 0
    fi

    if [[ -n "$wifi_port_name" ]] && output=$("$NET_SETUP" -setairportpower "$wifi_port_name" "$desired" 2>/dev/null); then
        log "Wi-Fi power set to $desired using ${wifi_port_name}."
        return 0
    fi

    log "Failed to set Wi-Fi power to $desired. Output: ${output:-none}"
    fail "Failed to set Wi-Fi power to $desired."
}

# Main control flow
main() {
    parse_args "$@"
    require_root
    load_hardware_ports

    if [[ -z "$wifi_device" && -z "$wifi_port_name" ]]; then
        log "No Wi-Fi interface found. Exiting."
        exit 2
    fi

    local wifi_state
    wifi_state="$(wifi_power_state)"
    if [[ "$wifi_state" == "Unknown" ]]; then
        fail "Unable to determine Wi-Fi state."
    fi

    local ethernet_active="false"
    if has_active_physical_ethernet; then
        ethernet_active="true"
    fi

    if [[ "$ethernet_active" == "true" && "$wifi_state" == "On" ]]; then
        set_wifi_power off
        exit 0
    elif [[ "$ethernet_active" == "false" && "$wifi_state" == "Off" ]]; then
        set_wifi_power on
        exit 0
    fi

    log_verbose "No change required (Ethernet active: ${ethernet_active}, Wi-Fi: ${wifi_state})."
    exit 2
}

main "$@"
