import Foundation
import AppKit

// Simple Wi-Fi power state model
enum WifiPower {
    case on
    case off
    case unknown
}

// Runs system commands and script actions safely
final class ScriptRunner {
    private let logPath = "/tmp/wifi-toggle.log"
    private let scriptPath = "/usr/local/sbin/wifi-toggle.sh"
    private let daemonPlist = "/Library/LaunchDaemons/com.user.wifitoggle.plist"

    // Run the toggle script with admin privileges
    func runScript() async {
        guard FileManager.default.isExecutableFile(atPath: scriptPath) else {
            log(message: "wifi-toggle.sh missing or not executable.")
            return
        }
        let command = """
        do shell script "\(scriptPath) --verbose" with administrator privileges
        """
        _ = await runAppleScript(command)
    }

    // Restart the LaunchDaemon using launchctl
    func restartDaemon() async {
        let commands = [
            ["/bin/launchctl", "bootout", "system", daemonPlist],
            ["/bin/launchctl", "bootstrap", "system", daemonPlist],
            ["/bin/launchctl", "kickstart", "-k", "system/com.user.wifitoggle"]
        ]
        for cmd in commands {
            _ = await runProcess(cmd)
        }
    }

    // Check if the LaunchDaemon is loaded
    func isDaemonRunning() -> Bool {
        let result = runSyncProcess(["/bin/launchctl", "print", "system/com.user.wifitoggle"])
        return result.exitCode == 0
    }

    // Read current Wi-Fi power state
    func readWifiState() async -> WifiPower {
        guard let device = await wifiPortOrDevice() else { return .unknown }
        let result = runSyncProcess(["/usr/sbin/networksetup", "-getairportpower", device])
        guard result.exitCode == 0 else { return .unknown }
        if result.output.contains("On") { return .on }
        if result.output.contains("Off") { return .off }
        return .unknown
    }

    // Check if any Ethernet interface is active
    func isEthernetActive() async -> Bool {
        let devices = await ethernetDevices()
        for dev in devices {
            let res = runSyncProcess(["/sbin/ifconfig", dev])
            if res.output.contains("status: active") {
                return true
            }
        }
        return false
    }

    // Read recent log lines from the script log
    func tailLog(lines: Int = 10) -> [String] {
        guard let data = FileManager.default.contents(atPath: logPath),
              let text = String(data: data, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").suffix(lines).map(String.init)
    }

    // Open the repo folder in Finder
    func openScriptLocation() {
        let url = URL(fileURLWithPath: "/Users/\(NSUserName())/network-scripts")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // Write a message to Console.app
    func log(message: String) {
        NSLog("NetworkToggle: %@", message)
    }

    // MARK: - Helpers

    // Resolve the Wi-Fi device from hardware ports
    private func wifiPortOrDevice() async -> String? {
        let list = runSyncProcess(["/usr/sbin/networksetup", "-listallhardwareports"])
        guard list.exitCode == 0 else { return nil }
        let lines = list.output.split(separator: "\n")
        var currentPort = ""
        for line in lines {
            if line.hasPrefix("Hardware Port:") {
                currentPort = line.replacingOccurrences(of: "Hardware Port: ", with: "")
            } else if line.hasPrefix("Device:") {
                let device = line.replacingOccurrences(of: "Device: ", with: "")
                if currentPort == "Wi-Fi" || currentPort == "AirPort" {
                    return device
                }
            }
        }
        return nil
    }

    // List non-virtual Ethernet devices
    private func ethernetDevices() async -> [String] {
        let list = runSyncProcess(["/usr/sbin/networksetup", "-listallhardwareports"])
        guard list.exitCode == 0 else { return [] }
        let lines = list.output.split(separator: "\n")
        var devices: [String] = []
        var currentPort = ""
        for line in lines {
            if line.hasPrefix("Hardware Port:") {
                currentPort = line.replacingOccurrences(of: "Hardware Port: ", with: "")
            } else if line.hasPrefix("Device:") {
                let device = line.replacingOccurrences(of: "Device: ", with: "")
                if currentPort != "Wi-Fi" && currentPort != "AirPort" && !isVirtualPort(name: currentPort) {
                    devices.append(device)
                }
            }
        }
        return devices
    }

    // Filter out virtual adapters by name
    private func isVirtualPort(name: String) -> Bool {
        switch name {
        case let n where n.contains("Bridge"),
             let n where n.contains("bridge"),
             let n where n.contains("VPN"),
             let n where n.contains("vpn"),
             let n where n.contains("Virtual"),
             let n where n.contains("virtual"),
             let n where n.contains("VMware"),
             let n where n.contains("Parallels"),
             let n where n.contains("vnic"),
             let n where n.contains("VLAN"),
             let n where n.contains("Bluetooth PAN"),
             let n where n.contains("Thunderbolt Bridge"):
            return true
        default:
            return false
        }
    }

    // Run a command asynchronously
    private func runProcess(_ command: [String]) async -> (output: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            Task.detached { [weak self] in
                let result = self?.runSyncProcess(command) ?? ("", 1)
                continuation.resume(returning: result)
            }
        }
    }

    // Run a command synchronously and capture output
    private func runSyncProcess(_ command: [String]) -> (output: String, exitCode: Int32) {
        var outputData = Data()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.first ?? "")
        process.arguments = Array(command.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return ("", 1)
        }

        outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return (output, process.terminationStatus)
    }

    // Run AppleScript with osascript
    private func runAppleScript(_ source: String) async -> Bool {
        await withCheckedContinuation { continuation in
            Task.detached {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-e", source]
                do {
                    try process.run()
                    process.waitUntilExit()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
}
