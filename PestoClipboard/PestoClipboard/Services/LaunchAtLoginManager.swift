import ServiceManagement
import Foundation
import Combine

/// Manages the "Launch at Login" functionality using the modern SMAppService API.
/// Requires macOS 13.0 or later.
class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published private(set) var isEnabled: Bool = false

    init() {
        refreshStatus()
    }

    /// Refresh the current status from the system.
    /// Important: Always read from SMAppService as users can change this in System Settings.
    func refreshStatus() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    /// Enable or disable launch at login.
    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                // Register the app to launch at login
                try SMAppService.mainApp.register()
            } else {
                // Unregister the app from launching at login
                try SMAppService.mainApp.unregister()
            }
            refreshStatus()
        } catch {
            print("Failed to \(enabled ? "enable" : "disable") launch at login: \(error)")
        }
    }

    /// Toggle the current state
    func toggle() {
        setEnabled(!isEnabled)
    }

    /// Static convenience method
    static func setLaunchAtLogin(_ enabled: Bool) {
        shared.setEnabled(enabled)
    }
}
