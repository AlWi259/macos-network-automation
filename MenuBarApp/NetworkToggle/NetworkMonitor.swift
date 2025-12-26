import Foundation
import SwiftUI
import Combine
import ServiceManagement

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

final class NetworkMonitor: ObservableObject {
    @Published var state = NetworkState(status: .unknown, daemonRunning: false)

    private let pollInterval: TimeInterval = 5
    private let runner = ScriptRunner()
    private var timer: AnyCancellable?

    var launchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func start() {
        refreshNow()
        timer = Timer.publish(every: pollInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshNow()
            }
    }

    func refreshNow() {
        Task {
            let status = await detectState()
            await MainActor.run {
                self.state = status
            }
        }
    }

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
