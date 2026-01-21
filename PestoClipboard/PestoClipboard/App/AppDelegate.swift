import AppKit
import SwiftUI
import KeyboardShortcuts

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var clipboardMonitor: ClipboardMonitor?
    private var historyManager: ClipboardHistoryManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Log accessibility permission status (but don't prompt - that happens in onboarding)
        if AccessibilityHelper.hasPermission {
            print("✅ Accessibility permission granted - paste will work")
        } else {
            print("ℹ️ Accessibility permission not granted yet - will be requested during onboarding if auto-paste is enabled")
        }

        // Initialize Core Data and services
        historyManager = ClipboardHistoryManager.shared
        SettingsManager.shared.configure(historyManager: historyManager!)
        clipboardMonitor = ClipboardMonitor(historyManager: historyManager!)

        // Initialize status bar (menu bar icon)
        statusBarController = StatusBarController(historyManager: historyManager!, clipboardMonitor: clipboardMonitor!)

        // Start monitoring clipboard
        clipboardMonitor?.startMonitoring()

        // Start auto-delete timer
        historyManager?.startAutoDeleteTimer()

        // Register global hotkey
        setupGlobalHotkey()

        print("🍝 Pesto Clipboard started - use Cmd+Shift+V to open")

        // Show onboarding wizard if not completed
        if !SettingsManager.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                OnboardingWindowController.shared.showOnboarding()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stopMonitoring()
        historyManager?.stopAutoDeleteTimer()
    }

    private func setupGlobalHotkey() {
        // Use KeyboardInterceptor with Cmd key buffering to prevent WinKey reaching RDP
        // Falls back to Carbon HotkeyManager if no accessibility permission
        KeyboardInterceptor.shared.start { [weak self] in
            print("⌨️ Global hotkey pressed")
            self?.statusBarController?.togglePopover()
        }
    }
}

// MARK: - Keyboard Shortcuts

extension KeyboardShortcuts.Name {
    static let openHistory = Self("openHistory", default: .init(.v, modifiers: [.command, .shift]))
}
