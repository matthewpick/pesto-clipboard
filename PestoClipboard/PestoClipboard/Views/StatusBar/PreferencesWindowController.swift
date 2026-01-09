import AppKit
import SwiftUI

// MARK: - Preferences Window Controller

class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?
    private var windowDelegate: PreferencesWindowDelegate?

    private init() {}

    func showPreferences() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let preferencesView = PreferencesView()

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = String(localized: "Pesto Clipboard Preferences")
        newWindow.contentView = NSHostingView(rootView: preferencesView)
        newWindow.center()
        newWindow.isReleasedWhenClosed = false

        let delegate = PreferencesWindowDelegate { [weak self] in
            self?.window = nil
            self?.windowDelegate = nil
        }
        newWindow.delegate = delegate
        windowDelegate = delegate

        window = newWindow
    }
}

// MARK: - Preferences Window Delegate

private class PreferencesWindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        // Enforce history limit when settings window closes
        ClipboardHistoryManager.shared.enforceHistoryLimit()
        onClose()
    }
}
