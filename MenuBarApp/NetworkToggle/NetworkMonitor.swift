import Foundation
import SwiftUI
import Combine
import ServiceManagement

// Simple status model for UI and icon logic
struct NetworkState {
    enum Status {
        case ethernetActiveWifiOff
        case wifiActiveNoEthernet
        case daemonMissing
        case unknown
    }

    var status: Status
    var daemonRunning: Bool
}

// Polls system state and exposes a simple view model
final class NetworkMonitor: ObservableObject {
    @Published var state = NetworkState(status: .unknown, daemonRunning: false)

    private let pollInterval: TimeInterval = 5
    private let runner = ScriptRunner()
    private var timer: AnyCancellable?

    // True when Launch at Login is enabled
    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    // Start periodic refreshes
    func start() {
        refreshNow()
        timer = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNow()
            }
    }

    // Refresh state immediately
    func refreshNow() {
        Task {
            let status = await detectState()
            await MainActor.run {
                self.state = status
            }
        }
    }

    // Toggle Launch at Login setting
    func toggleLaunchAtLogin() {
        do {
            if launchAtLoginEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("NetworkToggle: Failed to toggle login item: \(error)")
        }
    }

    // Detect daemon, Ethernet, and Wi-Fi status
    private func detectState() async -> NetworkState {
        let daemonRunning = runner.isDaemonRunning()
        guard daemonRunning else {
            return NetworkState(status: .daemonMissing, daemonRunning: false)
        }

        let wifiState = await runner.readWifiState()
        let ethernetActive = await runner.isEthernetActive()

        if ethernetActive && wifiState == .off {
            return NetworkState(status: .ethernetActiveWifiOff, daemonRunning: true)
        }
        if !ethernetActive && wifiState == .on {
            return NetworkState(status: .wifiActiveNoEthernet, daemonRunning: true)
        }
        return NetworkState(status: .unknown, daemonRunning: true)
    }
}
