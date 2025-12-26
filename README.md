# Wi-Fi Toggle Automation

Automatically turns Wi-Fi off when a wired Ethernet link is active and turns Wi-Fi back on when Ethernet is inactive. Built only with macOS system tools and currently tested on macOS 26.1 (Tahoe) on this host.

## How It Works
- A LaunchDaemon monitors `/Library/Preferences/SystemConfiguration/` for network changes and runs `wifi-toggle.sh`.
- The script discovers the Wi-Fi device dynamically, lists all non-Wi-Fi interfaces, filters out virtual adapters, and checks link status with `ifconfig`.
- Wi-Fi power is changed only when a real Ethernet link is active or inactive (idempotent). Exit codes: `0` action taken, `1` error, `2` no change needed.

## Files
- `wifi-toggle.sh` — Core logic with dry-run and verbose flags.
- `com.user.wifitoggle.plist` — LaunchDaemon definition watching network state changes.
- `install.sh` — Helper to install, reload, or uninstall the daemon.
- `.gitignore` — Ignores common macOS and editor artifacts.

## Prerequisites
- macOS Tahoe (26.1). Older versions may work but are not tested here.
- Admin/root privileges to install and control Wi-Fi power.
- Built-in tools only: `networksetup`, `ifconfig`, `launchctl`, `install`.

## Installation (manual)
```bash
# Run from the repo root
sudo install -d -m 755 /usr/local/sbin
sudo install -m 755 wifi-toggle.sh /usr/local/sbin/wifi-toggle.sh
sudo install -m 644 com.user.wifitoggle.plist /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo launchctl bootout system /Library/LaunchDaemons/com.user.wifitoggle.plist 2>/dev/null || true
sudo launchctl bootstrap system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo launchctl kickstart -k system/com.user.wifitoggle
```

## Installation (helper script)
```bash
sudo ./install.sh install   # install and start
sudo ./install.sh reload    # reinstall files and restart the daemon
sudo ./install.sh uninstall # stop and remove
```

## Usage & Testing
- Manual dry run: `sudo /usr/local/sbin/wifi-toggle.sh --dry-run --verbose`
- Verbose mode prints decisions to stdout; all runs log to `/tmp/wifi-toggle.log`.
- Launchd stdout/stderr go to `/tmp/wifi-toggle.launchd.log`.
- Check daemon status: `sudo launchctl print system/com.user.wifitoggle`

## Uninstall (manual)
```bash
sudo launchctl bootout system /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /Library/LaunchDaemons/com.user.wifitoggle.plist
sudo rm /usr/local/sbin/wifi-toggle.sh
```

## Troubleshooting
- Nothing happens: confirm the daemon is loaded (`launchctl print`), and that `/usr/local/sbin/wifi-toggle.sh` is executable by root.
- Wi-Fi not toggling: tail `/tmp/wifi-toggle.log` and `/tmp/wifi-toggle.launchd.log` to see decisions and errors.
- USB Ethernet not detected: ensure the adapter appears in `networksetup -listallhardwareports` and `ifconfig <device>` shows `status: active`.
- Still stuck: run the script manually with `--dry-run --verbose` to view decision logic without changing Wi-Fi power.

## Security Notes
- All binaries are absolute paths and PATH is restricted to system defaults.
- No external dependencies or downloads.
- Requires root because `networksetup -setairportpower` needs admin rights.

## License
MIT License

Copyright (c) 2024

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
