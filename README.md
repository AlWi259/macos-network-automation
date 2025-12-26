# Wi-Fi Toggle Automation

## Overview
This solution disables Wi-Fi whenever a physical Ethernet link is active and re-enables Wi-Fi as soon as the Ethernet cable is disconnected. It uses only built-in macOS utilities (`networksetup`, `system_profiler`, `ifconfig`, `launchctl`) and monitors the SystemConfiguration store so it reacts immediately to interface state changes without polling.

### Files
- `wifi-toggle.sh` – Bash script that detects the Wi-Fi hardware dynamically, verifies that an Ethernet interface is both physical and link-active, and toggles Wi-Fi only when a state change is required. All actions are logged to `/tmp/wifi-toggle.log`.
- `com.user.wifitoggle.plist` – LaunchDaemon configuration that runs the script at boot and on any change inside `/Library/Preferences/SystemConfiguration/`, which receives updates for every network event.

### Why a LaunchDaemon?
Changing Wi-Fi power via `networksetup -setairportpower` requires administrator privileges on macOS Ventura/Sonoma. Running this as a system LaunchDaemon (`/Library/LaunchDaemons`) ensures the script has root privileges and fires before any user logs in. A LaunchAgent would not have permission to toggle the hardware power without interactive authentication, so it is unsuitable here.

## Installation
Run the following from the project directory. Each command uses only built-in tooling.

```bash
# 1) Install the script with root-only write permissions.
sudo install -m 755 wifi-toggle.sh /usr/local/sbin/wifi-toggle.sh

# 2) Install the LaunchDaemon plist (owned by root:wheel, read-only).
sudo install -m 644 com.user.wifitoggle.plist /Library/LaunchDaemons/com.user.wifitoggle.plist

# 3) Tell launchd about the new daemon and start it immediately.
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo launchctl kickstart -k system/com.user.wifitoggle
```

The daemon now monitors `/Library/Preferences/SystemConfiguration/` for changes and runs `wifi-toggle.sh` at load and whenever the network stack reports a state transition.

## Verification & Logs
- Current status is written to `/tmp/wifi-toggle.log`. Tail this file while connecting/disconnecting Ethernet to confirm behavior.
- Launchd stdout/stderr are redirected to `/tmp/wifi-toggle.launchd.log`.
- To check the daemon state: `sudo launchctl print system/com.user.wifitoggle`.

## Uninstall
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /usr/local/sbin/wifi-toggle.sh
```

## Operational Notes
- The script avoids false positives by using `networksetup -listallhardwareports` to list all non-Wi-Fi interfaces, excludes obvious virtual adapters (bridges, VPNs, VM NICs, etc.), and then requires `ifconfig <device>` to report `status: active` before disabling Wi-Fi.
- Idempotency is enforced via `networksetup -getairportpower`: Wi-Fi is toggled only if its current state differs from what is required.
- All tooling is part of macOS; no third-party binaries or network access is needed.
