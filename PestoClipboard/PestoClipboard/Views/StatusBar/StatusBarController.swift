import AppKit
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var historyManager: ClipboardHistoryManager
    private var clipboardMonitor: ClipboardMonitor
    private var eventMonitor: Any?
    private var keyEventMonitor: Any?
    private var preferencesWindow: NSWindow?
    private var notificationObservers: [Any] = []

    init(historyManager: ClipboardHistoryManager, clipboardMonitor: ClipboardMonitor) {
        self.historyManager = historyManager
        self.clipboardMonitor = clipboardMonitor
        setupStatusItem()
        setupPanel()
        setupEventMonitor()
        setupNotificationObserver()
    }

    private func setupNotificationObserver() {
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .hideHistoryPanel,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.hidePanel()
            }
        )

        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .openHistoryPanel,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.showPanel()
            }
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Pesto Clipboard")
            button.image?.isTemplate = true
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func showMenu() {
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: String(localized: "Show Clipboard"), action: #selector(showClipboardAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Preferences"), action: #selector(showPreferencesAction), keyEquivalent: ","))
        menu.addItem(NSMenuItem(title: String(localized: "About Pesto Clipboard"), action: #selector(showAboutAction), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit"), action: #selector(quitAction), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showClipboardAction() {
        showPanel()
    }

    @objc private func showPreferencesAction() {
        // Hide the history panel first
        hidePanel()

        if preferencesWindow == nil {
            let preferencesView = PreferencesView()
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            preferencesWindow?.title = String(localized: "Pesto Clipboard Preferences")
            preferencesWindow?.contentView = NSHostingView(rootView: preferencesView)
            preferencesWindow?.center()
            preferencesWindow?.isReleasedWhenClosed = false
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAboutAction() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitAction() {
        NSApp.terminate(nil)
    }

    private func setupPanel() {
        let historyView = HistoryView(
            historyManager: historyManager,
            clipboardMonitor: clipboardMonitor,
            onDismiss: { [weak self] in
                self?.hidePanel()
            },
            onSettings: { [weak self] in
                self?.showPreferencesAction()
            }
        )

        panel = FloatingPanel(contentView: historyView)
    }

    private func setupEventMonitor() {
        // Close panel when clicking outside
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.panel.isVisible else { return }

            // Check if click is outside the panel
            let screenPoint = NSEvent.mouseLocation
            let panelFrame = self.panel.frame

            if !panelFrame.contains(screenPoint) {
                self.hidePanel()
            }
        }

        // Monitor for delete key presses when panel is visible and is key window
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.panel.isVisible, self.panel.isKeyWindow else { return event }

            // Don't intercept delete keys if a text field is being edited
            if let responder = self.panel.firstResponder, responder is NSTextView {
                return event
            }

            // Check for delete (backspace) key (keyCode 51) or forward delete (keyCode 117)
            if event.keyCode == 51 || event.keyCode == 117 {
                NotificationCenter.default.post(name: .deleteSelectedItem, object: nil)
                return nil // Consume the event
            }
            return event
        }
    }

    func togglePopover() {
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    func showPanel() {
        historyManager.fetchItems()
        panel.showPanel()
        NotificationCenter.default.post(name: .showHistoryPanel, object: nil)
    }

    func hidePanel() {
        panel.hidePanel()
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

// MARK: - Key-accepting Hosting View

class KeyAcceptingHostingView<Content: View>: NSHostingView<Content> {
    override var acceptsFirstResponder: Bool { true }
}

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

        // Panel configuration
        self.isFloatingPanel = true
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true

        // Set size constraints
        self.minSize = NSSize(width: Self.minWidth, height: Self.minHeight)
        self.maxSize = NSSize(width: Self.maxWidth, height: Self.maxHeight)

        // Set SwiftUI content using custom hosting view that accepts first responder
        let hosting = KeyAcceptingHostingView(rootView: contentView)
        hosting.frame = NSRect(x: 0, y: 0, width: width, height: height)
        hosting.autoresizingMask = [.width, .height]
        self.contentView = hosting
        self.hostingView = hosting

        // Restore last position or center on screen
        restorePosition()
    }

    // Store the hosting view to use as first responder
    private var hostingView: NSView?

    override var initialFirstResponder: NSView? {
        get { hostingView }  // Use hosting view, not text field
        set { }
    }

    func showPanel() {
        // Remember the frontmost app before we show panel
        previousApp = NSWorkspace.shared.frontmostApplication

        // Position panel near mouse cursor
        positionNearMouse()

        // Show panel as key window but don't activate our app
        // This keeps the menu bar showing the previous app
        self.makeKeyAndOrderFront(nil)

        // Make hosting view first responder so key events reach SwiftUI
        // but don't focus the text field
        if let hosting = hostingView {
            self.makeFirstResponder(hosting)
        }
    }

    private func positionNearMouse() {
        let mouseLocation = NSEvent.mouseLocation

        // Get the screen containing the mouse
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main else {
            return
        }

        let screenFrame = screen.visibleFrame
        let panelWidth = self.frame.width
        let panelHeight = self.frame.height

        // Position panel to bottom-right of mouse cursor
        var x = mouseLocation.x
        var y = mouseLocation.y - panelHeight

        // Clamp to screen bounds
        x = max(screenFrame.minX, min(x, screenFrame.maxX - panelWidth))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelHeight))

        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func hidePanel() {
        savePosition()
        self.orderOut(nil)

        // Return focus to the previous app
        if let app = previousApp {
            print("📱 Activating previous app: \(app.localizedName ?? "unknown") (PID: \(app.processIdentifier))")
            let success = app.activate(options: .activateIgnoringOtherApps)
            print("   Activation result: \(success ? "success" : "failed")")
        } else {
            print("⚠️ No previous app to activate")
        }

        previousApp = nil
    }

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
            self.setFrameOrigin(NSPoint(x: x, y: y))

            if let screen = NSScreen.main, !screen.visibleFrame.intersects(self.frame) {
                centerOnScreen()
            }
        } else {
            centerOnScreen()
        }
    }

    private func centerOnScreen() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.midY - frame.height / 2
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }

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
