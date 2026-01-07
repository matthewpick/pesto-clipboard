import AppKit

// MARK: - Event Monitor Manager

class EventMonitorManager {
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?

    private weak var panel: FloatingPanel?
    private let onClickOutside: () -> Void

    init(panel: FloatingPanel, onClickOutside: @escaping () -> Void) {
        self.panel = panel
        self.onClickOutside = onClickOutside
        setupMonitors()
    }

    private func setupMonitors() {
        setupGlobalClickMonitor()
        setupLocalKeyMonitor()
    }

    private func setupGlobalClickMonitor() {
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self = self,
                  let panel = self.panel,
                  panel.isVisible else { return }

            let screenPoint = NSEvent.mouseLocation
            let panelFrame = panel.frame

            if !panelFrame.contains(screenPoint) {
                self.onClickOutside()
            }
        }
    }

    private func setupLocalKeyMonitor() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let panel = self.panel,
                  panel.isVisible,
                  panel.isKeyWindow else { return event }

            // Don't intercept delete keys if a text field is being edited
            if let responder = panel.firstResponder, responder is NSTextView {
                return event
            }

            // Check for delete (backspace) key or forward delete
            if event.keyCode == Constants.deleteKeyCode || event.keyCode == Constants.forwardDeleteKeyCode {
                AppEventBus.shared.deleteSelectedItem()
                return nil
            }
            return event
        }
    }

    deinit {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
