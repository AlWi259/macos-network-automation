# Network Toggle Menu Bar App

Native macOS menu bar companion for `wifi-toggle.sh`. It displays current network state, lets you trigger the toggle script, view recent logs, and restart the LaunchDaemon.

## Features
- Menu bar icon updates every 5 seconds based on Ethernet/Wi-Fi state.
- Shows daemon status and last 10 log lines from `/tmp/wifi-toggle.log`.
- Manual toggle and restart controls.
- Optional launch-at-login using `SMAppService`.

## Requirements
- macOS 13+ (tested on macOS 26.1 Tahoe).
- Existing automation installed:
  - `/Library/LaunchDaemons/com.user.wifitoggle.plist`
  - `/usr/local/sbin/wifi-toggle.sh`
  - Logs at `/tmp/wifi-toggle.log`
- Xcode 15+ and a local signing identity (Development).

## Build & Run
1. Open `MenuBarApp/NetworkToggle.xcodeproj` in Xcode.
2. Set signing for target `NetworkToggle` (Bundle ID `com.user.networktoggle`).
3. Build & Run. The app sits in the menu bar; first launch shows onboarding text.

## Permissions
- Running the toggle needs admin rights. The app uses AppleScript `do shell script ... with administrator privileges` only for the fixed path `/usr/local/sbin/wifi-toggle.sh`.
- When prompted, grant permission; canceling will abort the toggle.

## Login Item
- In the menu, toggle "Launch at Login" to register/unregister with `SMAppService`.

## Troubleshooting
- Icon shows ⚠️: daemon not loaded. Click "Restart Daemon".
- No logs: ensure `/tmp/wifi-toggle.log` exists and is readable.
- Toggle fails: make sure `/usr/local/sbin/wifi-toggle.sh` is executable and works manually.
- If network status is stale, use "Refresh Now".

## Uninstall
- Quit the app from the menu bar, remove it from `/Applications` if you copied it there, and remove the login item via "Launch at Login".

## Notes
- App is sandbox-friendly but not sandboxed by default. No external dependencies.
