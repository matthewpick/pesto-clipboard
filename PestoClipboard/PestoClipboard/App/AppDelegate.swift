import AppKit
import SwiftUI
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var clipboardMonitor: ClipboardMonitor?
    private var historyManager: ClipboardHistoryManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check for accessibility permissions (needed for paste simulation)
        let hasPermission = AccessibilityHelper.checkAndRequestPermission()
        if hasPermission {
            print("✅ Accessibility permission granted - paste will work")
        } else {
            print("⚠️ Accessibility permission NOT granted - paste will NOT work until permission is granted")
            print("   Go to: System Settings > Privacy & Security > Accessibility > Enable PestoClipboard")
        }

        // Initialize Core Data and services
        historyManager = ClipboardHistoryManager.shared
        clipboardMonitor = ClipboardMonitor(historyManager: historyManager!)

        // Initialize status bar (menu bar icon)
        statusBarController = StatusBarController(historyManager: historyManager!, clipboardMonitor: clipboardMonitor!)

        // Start monitoring clipboard
        clipboardMonitor?.startMonitoring()

        // Register global hotkey
        setupGlobalHotkey()

        print("🍝 Pesto Clipboard started - use Cmd+Shift+V to open")
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
    }

    private func setupGlobalHotkey() {
        KeyboardShortcuts.onKeyDown(for: .openHistory) { [weak self] in
            self?.statusBarController?.togglePopover()
        }
    }
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let openHistory = Self("openHistory", default: .init(.v, modifiers: [.command, .shift]))
}
