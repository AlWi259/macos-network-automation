# Changelog

## [1.1.2] - 2025-12-26

### Changed
- Added clear English comments across shell scripts and Swift UI code
- Improved developer readability without changing runtime behavior

## [1.1.1] - 2025-12-26

### Changed
- README refreshed with clearer formatting, repo path alignment, and configuration notes
- Added repository metadata suggestions and a short security section

### Fixed
- Documentation now uses consistent fenced code blocks and copy‑paste friendly commands

## [1.1.0] - 2025-12-26

### Added
- Interactive installer (`install.sh`), uninstaller (`uninstall.sh`), and status helper (`check-status.sh`)
- SwiftUI menu bar app scaffold under `MenuBarApp/` with daemon controls and log viewer
- Logging enhancements and verbose/debug flags for troubleshooting

### Changed
- README and docs expanded with install, usage, troubleshooting, and structure details
- Release artifacts (.gitignore, LICENSE, and project files) aligned for open-source distribution

### Fixed
- Wi-Fi power detection tolerates localized `networksetup` output (On/Off/Ein/Aus) and USB Ethernet adapters
- Cleaned logging noise and argument parsing to avoid false errors

### Security
- Maintained root-only operations with absolute paths and ShellCheck-friendly hardening

## [1.0.0] - 2025-12-26

### Added
- Initial release with automatic Wi-Fi toggle functionality
- LaunchDaemon for background automation
- Native macOS Menu Bar app
- Support for USB Ethernet adapters (docking stations)
- Dynamic network interface detection
- Comprehensive logging system
- English language throughout

### Technical Details
- Bash script with idempotency checks
- Performance optimized (<200ms execution)
- Security hardened (input validation, absolute paths)
- ShellCheck-friendly code
