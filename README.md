# 🛰️ Network Toggle

Automatic Wi‑Fi power control on macOS: disables Wi‑Fi when a wired Ethernet link is active and re‑enables Wi‑Fi when Ethernet disconnects. Includes a LaunchDaemon for background automation and an optional SwiftUI menu bar companion.

![Menu bar icon placeholder](docs/assets/menubar-placeholder.png "Menu bar icon preview")

[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.1.0-black.svg)](CHANGELOG.md)

## Table of Contents
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Menu Bar App](#menu-bar-app)
- [Uninstallation](#uninstallation)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Features
- ⚡ Automatic Wi‑Fi toggle when wired Ethernet link is active
- 🧭 Dynamic hardware discovery (no hardcoded interface names)
- 🧩 USB Ethernet/docking station support
- 🔒 LaunchDaemon with root permissions for reliable hardware control
- 📜 Logging to `/tmp/wifi-toggle.log` and LaunchDaemon log
- 🧪 Dry-run (`--dry-run`) and verbose (`--verbose`) modes for safe testing
- 🖥️ Optional SwiftUI menu bar app for status, logs, and manual actions

## Prerequisites
- macOS 13.0 (Ventura) or later (confirmed on macOS 26.1 Tahoe)
- Administrator privileges (sudo)
- Xcode + Command Line Tools (only if building the menu bar app)

## Installation
### Quick install (interactive)
```bash
cd ~/network-scripts
sudo ./install.sh       # installs script + LaunchDaemon, optional menu bar app
./check-status.sh       # verify daemon and logs
```

### Manual install
```bash
cd ~/network-scripts
sudo install -d -m 755 /usr/local/sbin
sudo install -m 755 wifi-toggle.sh /usr/local/sbin/wifi-toggle.sh
sudo install -m 644 com.user.wifitoggle.plist /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo launchctl bootout system /Library/LaunchDaemons/com.user.wifitoggle.plist 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo launchctl kickstart -k system/com.user.wifitoggle
```

### Verify installation
```bash
./check-status.sh
sudo /usr/local/sbin/wifi-toggle.sh --dry-run --verbose
sudo launchctl print system/com.user.wifitoggle
sudo tail -n 5 /tmp/wifi-toggle.log
```

## Usage
- Automation: LaunchDaemon monitors `/Library/Preferences/SystemConfiguration/` and calls `wifi-toggle.sh`.
- Manual run: `sudo /usr/local/sbin/wifi-toggle.sh [--dry-run] [--verbose|-v] [--help|-h]`
  - `--dry-run` prints intended actions without changing Wi‑Fi power.
  - `--verbose` echoes decisions to stdout in addition to the log file.
- Logs: `/tmp/wifi-toggle.log` (script) and `/tmp/wifi-toggle.launchd.log` (daemon stdout/err).
- Behavior: Wi‑Fi turns off when any non-virtual Ethernet interface reports `status: active`; re-enables when not.

## Menu Bar App
- Location: `MenuBarApp/NetworkToggle.xcodeproj` (macOS 13+ SwiftUI).
- Icons:
  - 🔌 (`cable.connector`) — Ethernet active, Wi‑Fi off
  - 📡 (`wifi`) — Wi‑Fi active, no Ethernet
  - ⚠️ (`exclamationmark.triangle`) — Daemon not running/unknown
- Menu items:
  - Current status display
  - Toggle Wi‑Fi (runs `wifi-toggle.sh` with admin prompt)
  - Refresh Now
  - Daemon status/restart
  - Show Recent Logs (last 10 lines from `/tmp/wifi-toggle.log`)
  - Launch at Login toggle (uses `SMAppService`)
  - Open script location
  - Quit
- Build: open in Xcode, set a Development signing identity, build & run. Optional install to `/Applications` via `install.sh` prompt.

## Uninstallation
### Interactive
```bash
cd ~/network-scripts
sudo ./uninstall.sh
```

### Manual
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /usr/local/sbin/wifi-toggle.sh
sudo rm -rf /Applications/NetworkToggle.app    # if installed
```

## Troubleshooting
- Daemon not loading: `sudo launchctl print system/com.user.wifitoggle`; check plist permissions (644, root:wheel).
- USB Ethernet not detected: ensure the adapter appears in `networksetup -listallhardwareports` and `ifconfig <dev>` shows `status: active`; script filters virtual interfaces.
- Permissions: `sudo chown root:wheel /usr/local/sbin/wifi-toggle.sh /Library/LaunchDaemons/com.user.wifitoggle.plist`.
- Gatekeeper (menu app): if blocked, right-click > Open once, or codesign locally in Xcode.
- Logs empty: ensure the daemon is loaded; run script manually with `--verbose` to confirm logging.
- Wi‑Fi state seems wrong: reinstall `wifi-toggle.sh` to `/usr/local/sbin`, then run `sudo /usr/local/sbin/wifi-toggle.sh --verbose` and check `/tmp/wifi-toggle.log` for the “Wi-Fi power query” line (handles localized On/Off/EIN/AUS output).

## Development
- Project structure:
```
network-scripts/
├── README.md
├── CHANGELOG.md
├── LICENSE
├── .gitignore
├── wifi-toggle.sh
├── com.user.wifitoggle.plist
├── install.sh
├── uninstall.sh
├── check-status.sh
└── MenuBarApp/
    ├── NetworkToggle.xcodeproj
    └── NetworkToggle/
        ├── NetworkToggleApp.swift
        ├── MenuBarController.swift
        ├── NetworkMonitor.swift
        └── ScriptRunner.swift
```
- Build menu app: open `MenuBarApp/NetworkToggle.xcodeproj` in Xcode 15+, set signing, build/run.
- Tests: use `--dry-run` and `check-status.sh` to validate behavior; manual Ethernet connect/disconnect to observe toggling.
- Coding standards: Shell scripts use `set -euo pipefail`, absolute paths, and no external dependencies; Swift uses async/await and `Process` without shell injection.

## Contributing
- Please open issues or pull requests with a clear description and steps to reproduce.
- Follow shell style (ShellCheck-friendly) and Swift naming conventions.
- Keep documentation in English and update the changelog for user-facing changes.

## License
MIT License. See [LICENSE](LICENSE) for details.
