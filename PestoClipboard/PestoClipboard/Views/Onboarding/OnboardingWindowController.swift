import AppKit
import SwiftUI

class OnboardingWindowController {
    static let shared = OnboardingWindowController()

    private var window: NSWindow?

    private init() {}

    func showOnboarding(completion: (() -> Void)? = nil) {
        // Close existing window if present
        window?.close()

        let onboardingView = OnboardingView {
            self.closeOnboarding(showHistoryPanel: true)
            completion?()
        }

        let hostingView = NSHostingView(rootView: onboardingView)

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window?.title = "Welcome to Pesto Clipboard"
        window?.contentView = hostingView
        window?.center()
        window?.isReleasedWhenClosed = false

        // Make window modal-like by setting level
        window?.level = .modalPanel

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeOnboarding(showHistoryPanel: Bool = false) {
        window?.close()
        window = nil

        if showHistoryPanel {
            // Small delay to let window close, then show history panel
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NotificationCenter.default.post(name: .openHistoryPanel, object: nil)
            }
        }
    }

    var isOnboardingVisible: Bool {
        window?.isVisible ?? false
    }
}
