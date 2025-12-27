import SwiftUI
import AppKit
import Combine

// Controls the menu bar item, icon state, and menu actions
final class MenuBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let monitor = NetworkMonitor()
    private let runner = ScriptRunner()
    private var cancellables = Set<AnyCancellable>()
    private var showOnboarding = UserDefaults.standard.bool(forKey: "NetworkToggleDidOnboard") == false

    // Build the menu and start monitoring state
    init() {
        configureMenu()
        bindMonitor()
        monitor.start()
        if showOnboarding {
            UserDefaults.standard.set(true, forKey: "NetworkToggleDidOnboard")
            logOnboarding()
        }
    }

    // Create the initial menu UI and icon
    private func configureMenu() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Network Toggle")
        }
        statusItem.menu = buildMenu(state: monitor.state, logs: [])
    }

    // Subscribe to network state changes
    private func bindMonitor() {
        monitor.$state
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                self?.refresh(state: state)
            }
            .store(in: &cancellables)
    }

    // Refresh icon and menu when state changes
    private func refresh(state: NetworkState) {
        updateIcon(state: state)
        reloadMenu(state: state)
    }

    // Update the status bar icon based on state
    private func updateIcon(state: NetworkState) {
        guard let button = statusItem.button else { return }
        let symbol: String
        switch state.status {
        case .ethernetActiveWifiOff:
            symbol = "cable.connector"
        case .wifiActiveNoEthernet:
            symbol = "wifi"
        case .daemonMissing:
            symbol = "exclamationmark.triangle"
        case .unknown:
            symbol = "questionmark.circle"
        }
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Network Toggle")
    }

    // Rebuild menu items with fresh logs and status
    private func reloadMenu(state: NetworkState) {
        let logs = runner.tailLog()
        statusItem.menu = buildMenu(state: state, logs: logs)
    }

    // Build the menu structure for the status item
    private func buildMenu(state: NetworkState, logs: [String]) -> NSMenu {
        let menu = NSMenu()

        let statusTitle: String
        switch state.status {
        case .ethernetActiveWifiOff:
            statusTitle = "Ethernet Active (Wi-Fi Off)"
        case .wifiActiveNoEthernet:
            statusTitle = "Wi-Fi Active (No Ethernet)"
        case .daemonMissing:
            statusTitle = "Daemon Not Running"
        case .unknown:
            statusTitle = "Status Unknown"
        }
        menu.addItem(withTitle: statusTitle, action: nil, keyEquivalent: "")

        menu.addItem(NSMenuItem.separator())

        let toggleItem = NSMenuItem(title: "Toggle Wi-Fi", action: #selector(handleToggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(handleRefresh), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let daemonTitle = "Daemon Status: \(state.daemonRunning ? "Running" : "Stopped")"
        let daemonItem = NSMenuItem(title: daemonTitle, action: #selector(handleRestartDaemon), keyEquivalent: "")
        daemonItem.target = self
        menu.addItem(daemonItem)

        menu.addItem(NSMenuItem.separator())

        let logsItem = NSMenuItem(title: "Show Recent Logs", action: nil, keyEquivalent: "")
        let logsMenu = NSMenu()
        if logs.isEmpty {
            logsMenu.addItem(withTitle: "No logs available", action: nil, keyEquivalent: "")
        } else {
            for line in logs {
                logsMenu.addItem(withTitle: line, action: nil, keyEquivalent: "")
            }
        }
        menu.setSubmenu(logsMenu, for: logsItem)
        menu.addItem(logsItem)

        let loginItem = NSMenuItem(title: monitor.launchAtLoginEnabled ? "Launch at Login: On" : "Launch at Login: Off", action: #selector(handleToggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)

        let openScriptItem = NSMenuItem(title: "Open Script Location", action: #selector(handleOpenScript), keyEquivalent: "")
        openScriptItem.target = self
        menu.addItem(openScriptItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // Run the toggle script with admin prompt
    @objc private func handleToggle() {
        Task { await runner.runScript() }
    }

    // Force a state refresh
    @objc private func handleRefresh() {
        monitor.refreshNow()
    }

    // Restart the LaunchDaemon
    @objc private func handleRestartDaemon() {
        Task { await runner.restartDaemon() }
    }

    // Toggle launch at login and update the menu
    @objc private func handleToggleLogin() {
        monitor.toggleLaunchAtLogin()
        reloadMenu(state: monitor.state)
    }

    // Open the repo folder in Finder
    @objc private func handleOpenScript() {
        runner.openScriptLocation()
    }

    // Quit the menu bar app
    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }

    // Write a one-time onboarding log message
    private func logOnboarding() {
        runner.log(message: "Network Toggle menu bar app installed. It reflects wifi-toggle.sh state.")
    }
}
