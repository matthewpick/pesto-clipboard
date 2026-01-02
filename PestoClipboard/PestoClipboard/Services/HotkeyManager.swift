import KeyboardShortcuts
import AppKit

/// Manages global keyboard shortcuts for the app.
/// Uses the KeyboardShortcuts library by Sindre Sorhus.
struct HotkeyManager {
    /// Register all global hotkeys
    static func registerHotkeys(openHistoryAction: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .openHistory) {
            openHistoryAction()
        }
    }

    /// Unregister all hotkeys (call on app termination if needed)
    static func unregisterHotkeys() {
        KeyboardShortcuts.reset(.openHistory)
    }
}
