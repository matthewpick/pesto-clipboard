import AppKit
import ApplicationServices

struct AccessibilityHelper {
    /// Check if we have accessibility permissions
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user to grant accessibility permissions
    /// Opens System Settings to the Accessibility pane
    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Check permission and prompt if needed, returns true if we have permission
    @discardableResult
    static func checkAndRequestPermission() -> Bool {
        if hasPermission {
            return true
        }

        requestPermission()
        return false
    }
}
