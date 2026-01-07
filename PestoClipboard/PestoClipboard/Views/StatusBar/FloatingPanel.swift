import AppKit
import SwiftUI

// MARK: - Floating Panel

class FloatingPanel: NSPanel {
    private static let defaultWidth: CGFloat = 320
    private static let defaultHeight: CGFloat = 420
    private static let minWidth: CGFloat = 280
    private static let minHeight: CGFloat = 300
    private static let maxWidth: CGFloat = 600
    private static let maxHeight: CGFloat = 800

    private static let positionXKey = "FloatingPanelPositionX"
    private static let positionYKey = "FloatingPanelPositionY"
    private static let widthKey = "FloatingPanelWidth"
    private static let heightKey = "FloatingPanelHeight"

    /// The app that was frontmost before we showed the panel
    private var previousApp: NSRunningApplication?

    /// Store the hosting view to use as first responder
    private var hostingView: NSView?

    init<Content: View>(contentView: Content) {
        // Restore saved size or use defaults
        let width = UserDefaults.standard.object(forKey: Self.widthKey) as? CGFloat ?? Self.defaultWidth
        let height = UserDefaults.standard.object(forKey: Self.heightKey) as? CGFloat ?? Self.defaultHeight

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )

        configurePanel()
        setupContent(contentView, width: width, height: height)
        restorePosition()
    }

    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
        maxSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)
    }

    private func setupContent<Content: View>(_ contentView: Content, width: CGFloat, height: CGFloat) {
        let hosting = KeyAcceptingHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting
    }

    override var initialFirstResponder: NSView? {
        get { hostingView }
        set { }
    }

    // MARK: - Show/Hide

    func showPanel() {
        previousApp = NSWorkspace.shared.frontmostApplication
        positionNearMouse()
        makeKeyAndOrderFront(nil)

        if let hosting = hostingView {
            makeFirstResponder(hosting)
        }
    }

    func hidePanel() {
        savePosition()
        orderOut(nil)
        activatePreviousApp()
        previousApp = nil
    }

    private func activatePreviousApp() {
        guard let app = previousApp else { return }
        app.activate(options: .activateIgnoringOtherApps)
    }

    // MARK: - Positioning

    private func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation

        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let panelWidth = frame.width
        let panelHeight = frame.height

        var x = mouseLocation.x
        var y = mouseLocation.y - panelHeight

        x = max(screenFrame.minX, min(x, screenFrame.maxX - panelWidth))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelHeight))

        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Position Persistence

    private func savePosition() {
        UserDefaults.standard.set(frame.origin.x, forKey: Self.positionXKey)
        UserDefaults.standard.set(frame.origin.y, forKey: Self.positionYKey)
        UserDefaults.standard.set(frame.width, forKey: Self.widthKey)
        UserDefaults.standard.set(frame.height, forKey: Self.heightKey)
    }

    private func restorePosition() {
        let savedX = UserDefaults.standard.object(forKey: Self.positionXKey) as? CGFloat
        let savedY = UserDefaults.standard.object(forKey: Self.positionYKey) as? CGFloat

        if let x = savedX, let y = savedY {
            setFrameOrigin(NSPoint(x: x, y: y))

            if let screen = NSScreen.main, !screen.visibleFrame.intersects(frame) {
                centerOnScreen()
            }
        } else {
            centerOnScreen()
        }
    }

    // MARK: - Overrides

    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        savePosition()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(frameRect, display: flag)
        savePosition()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Key-accepting Hosting View

class KeyAcceptingHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { true }
}
