import SwiftUI
import AppKit

// App entry for a menu bar utility
@main
struct NetworkToggleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // No settings UI; menu bar only
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// App delegate to configure the menu bar controller
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: MenuBarController?

    // Initialize the menu bar item at launch
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        controller = MenuBarController()
    }
}
