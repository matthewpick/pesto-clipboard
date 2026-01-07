import AppKit
import Combine
import SwiftUI

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var eventMonitorManager: EventMonitorManager?
    private var historyManager: ClipboardHistoryManager
    private var clipboardMonitor: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()

    init(historyManager: ClipboardHistoryManager, clipboardMonitor: ClipboardMonitor) {
        self.historyManager = historyManager
        self.clipboardMonitor = clipboardMonitor
        setupStatusItem()
        setupPanel()
        setupEventMonitor()
        setupEventSubscriptions()
    }

    private func setupEventSubscriptions() {
        AppEventBus.shared.publisher(for: .hideHistoryPanel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.hidePanel()
            }
            .store(in: &cancellables)

        AppEventBus.shared.publisher(for: .openHistoryPanel)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.showPanel()
            }
            .store(in: &cancellables)
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
        hidePanel()
        PreferencesWindowController.shared.showPreferences()
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
        eventMonitorManager = EventMonitorManager(panel: panel) { [weak self] in
            self?.hidePanel()
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
        AppEventBus.shared.showHistoryPanel()
    }

    func hidePanel() {
        panel.hidePanel()
    }

    deinit {
        eventMonitorManager = nil
        cancellables.removeAll()
    }
}
