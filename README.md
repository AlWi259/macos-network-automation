# 🛰️ Network Toggle

Automatic Wi‑Fi power control for macOS. Disables Wi‑Fi when a wired Ethernet link is active and re‑enables Wi‑Fi when Ethernet disconnects.

**Badges:** macOS 13+ • MIT License • v1.1.1

**What’s new:** v1.1.1 refreshes documentation, metadata, and configuration notes. See [CHANGELOG.md](CHANGELOG.md).

## Table of Contents
- [🛰️ Network Toggle](#️-network-toggle)
  - [Table of Contents](#table-of-contents)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
    - [Quick install (interactive)](#quick-install-interactive)
    - [Manual install](#manual-install)
    - [Verify installation](#verify-installation)
  - [Usage](#usage)
    - [Manual run](#manual-run)
    - [CLI flags](#cli-flags)
  - [Configuration \& Behavior](#configuration--behavior)
  - [Security Considerations](#security-considerations)
  - [Menu Bar App](#menu-bar-app)
  - [Uninstallation](#uninstallation)
    - [Interactive](#interactive)
    - [Manual](#manual)
  - [Troubleshooting](#troubleshooting)
  - [Development](#development)
    - [Project structure](#project-structure)
    - [Developer notes](#developer-notes)
  - [Contributing](#contributing)
  - [Repository Metadata](#repository-metadata)
  - [License](#license)

## Features
- ⚡ Automatic Wi‑Fi toggle on wired Ethernet link
- 🧭 Dynamic hardware discovery (no hardcoded interface names)
- 🧩 USB Ethernet/docking station support
- 🔒 LaunchDaemon with root permissions for reliable hardware control
- 📜 Logging to `/tmp/wifi-toggle.log` and `/tmp/wifi-toggle.launchd.log`
- 🧪 Dry-run (`--dry-run`) and verbose (`--verbose`) modes for safe testing
- 🖥️ Optional SwiftUI menu bar app for status, logs, and manual actions

## Prerequisites
- macOS 13.0 (Ventura) or later (confirmed on macOS 26.1 Tahoe)
- Administrator privileges (sudo)
- Xcode + Command Line Tools (only if building the menu bar app)

## Installation
### Quick install (interactive)
```bash
cd ~/macos-network-automation
sudo ./install.sh
./check-status.sh
```

### Manual install
```bash
cd ~/macos-network-automation
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
### Manual run
```bash
sudo /usr/local/sbin/wifi-toggle.sh --dry-run --verbose
```

### CLI flags
- `--dry-run` prints intended actions without changing Wi‑Fi power.
- `--verbose` echoes decisions to stdout in addition to the log file.
- `--help` shows usage.

## Configuration & Behavior
- **Interface detection:** all non‑Wi‑Fi hardware ports from `networksetup -listallhardwareports`, minus virtual adapters; link check via `ifconfig <dev>` with `status: active`.
- **Logs:** `/tmp/wifi-toggle.log` (script) and `/tmp/wifi-toggle.launchd.log` (daemon stdout/err). `/tmp` is intentionally ephemeral and resets on reboot.
- **Testing:** use `--dry-run` and `--verbose` for safe verification without changing Wi‑Fi power.
- **LaunchDaemon label:** to customize `com.user.wifitoggle`, rename the plist file, update the `Label` key, and reload with `launchctl bootout/bootstrap`.

## Security Considerations
- Requires root/LaunchDaemon because macOS restricts `networksetup -setairportpower` to administrators.
- The script only toggles Wi‑Fi power and reads local interface state; it does not send data externally.
- All commands use absolute paths and built‑in macOS binaries only.

## Menu Bar App
- Location: `MenuBarApp/NetworkToggle.xcodeproj` (macOS 13+ SwiftUI).
- Icons:
  - 🔌 (`cable.connector`) — Ethernet active, Wi‑Fi off
  - 📡 (`wifi`) — Wi‑Fi active, no Ethernet
  - ⚠️ (`exclamationmark.triangle`) — daemon not running/unknown
- Menu items:
  - Current status display
  - Toggle Wi‑Fi (runs `wifi-toggle.sh` with admin prompt)
  - Refresh Now
  - Daemon status/restart
  - Show Recent Logs (last 10 lines from `/tmp/wifi-toggle.log`)
  - Launch at Login toggle (uses `SMAppService`)
  - Open script location
  - Quit
- Build: open in Xcode, set a Development signing identity, build & run. Optional install to `/Applications` via `install.sh`.

## Uninstallation
### Interactive
```bash
cd ~/macos-network-automation
sudo ./uninstall.sh
```

### Manual
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /usr/local/sbin/wifi-toggle.sh
sudo rm -rf /Applications/NetworkToggle.app
```

## Troubleshooting
- Daemon not loading: `sudo launchctl print system/com.user.wifitoggle`; check plist permissions (644, root:wheel).
- USB Ethernet not detected: ensure the adapter appears in `networksetup -listallhardwareports` and `ifconfig <dev>` shows `status: active`; script filters virtual interfaces.
- Permissions: `sudo chown root:wheel /usr/local/sbin/wifi-toggle.sh /Library/LaunchDaemons/com.user.wifitoggle.plist`.
- Gatekeeper (menu app): if blocked, right-click > Open once, or codesign locally in Xcode.
- Logs empty: ensure the daemon is loaded; run script manually with `--verbose` to confirm logging.
- Localized Wi‑Fi states (EIN/AUS) are handled when parsing `networksetup -getairportpower`.

## Development
### Project structure
```text
macos-network-automation/
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
    ├── NetworkToggle/
    │   ├── NetworkToggleApp.swift
    │   ├── MenuBarController.swift
    │   ├── NetworkMonitor.swift
    │   └── ScriptRunner.swift
    └── README_APP.md
```

### Developer notes
- macOS 13+ and Xcode 15+ required to build the menu bar app.
- Build locally: open `MenuBarApp/NetworkToggle.xcodeproj`, set signing, build & run.
- End‑to‑end test: connect/disconnect Ethernet, then check `/tmp/wifi-toggle.log` and `/tmp/wifi-toggle.launchd.log`.
- Run `--dry-run` and `check-status.sh` after changes to validate behavior.

## Contributing
- Create a feature branch from `main` (e.g. `feature/your-change`).
- Run `sudo /usr/local/sbin/wifi-toggle.sh --dry-run --verbose` to validate behavior.
- Update `README.md` and `CHANGELOG.md` for any user‑visible changes.
- Open a PR with a clear summary and test notes.

## Repository Metadata
- **Suggested GitHub description:** “Automatic Wi‑Fi toggle on macOS when Ethernet is active, with LaunchDaemon automation and optional menu bar app.”
- **Suggested topics:** `macos`, `wifi`, `ethernet`, `launchd`, `automation`, `swiftui`, `menu-bar-app`

## License
MIT License. See [LICENSE](LICENSE) for details.