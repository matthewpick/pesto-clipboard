import AppKit
import Combine
import SwiftUI

@MainActor
class HistoryViewModel: ObservableObject {
    // MARK: - Dependencies

    let historyManager: ClipboardHistoryManager
    var clipboardMonitor: ClipboardMonitor
    var settings: SettingsManager

    // MARK: - Published State

    @Published var searchText: String = ""
    @Published var selectedIndex: Int = 0
    @Published var showStarredOnly: Bool = false
    @Published var itemToEdit: ClipboardItem?

    // Internal state for scroll behavior
    var suppressScrollToTop: Bool = false

    // MARK: - Decorator Cache

    private var decoratorCache: [UUID: ClipboardItemDecorator] = [:]

    // MARK: - Computed Properties

    var filteredItems: [ClipboardItem] {
        if showStarredOnly {
            return historyManager.items.filter { $0.isPinned }
        }
        return historyManager.items
    }

    /// Returns filtered items wrapped in decorators for lazy loading.
    /// Reuses existing decorators for items that are still present.
    var filteredDecorators: [ClipboardItemDecorator] {
        let items = filteredItems
        var result: [ClipboardItemDecorator] = []

        for item in items {
            if let existing = decoratorCache[item.id] {
                result.append(existing)
            } else {
                let decorator = ClipboardItemDecorator(item: item)
                decoratorCache[item.id] = decorator
                result.append(decorator)
            }
        }

        // Clean up decorators for items no longer present
        let currentIds = Set(items.map { $0.id })
        decoratorCache = decoratorCache.filter { currentIds.contains($0.key) }

        return result
    }

    var hasError: Bool {
        historyManager.lastError != nil
    }

    // MARK: - Cancellables

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        historyManager: ClipboardHistoryManager,
        clipboardMonitor: ClipboardMonitor,
        settings: SettingsManager = .shared
    ) {
        self.historyManager = historyManager
        self.clipboardMonitor = clipboardMonitor
        self.settings = settings

        setupBindings()
    }

    private func setupBindings() {
        // Forward changes from dependencies to trigger UI refresh
        Publishers.Merge3(
            historyManager.$items.map { _ in () },
            clipboardMonitor.$isPaused.map { _ in () },
            settings.$plainTextMode.map { _ in () }
        )
        .dropFirst()
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                // Cached decorators read their mutable metadata live, so a save that
                // changed an item (star, edit) publishes nothing by itself — poke the
                // rows so they re-render. Deferred, so this never fires mid-update.
                for decorator in self.decoratorCache.values {
                    decorator.refreshMetadata()
                }
                self.objectWillChange.send()
            }
        }
        .store(in: &cancellables)

        setupSearchBinding()
    }

    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] query in
                guard let self else { return }
                if query.isEmpty {
                    self.historyManager.fetchItems()
                } else {
                    self.historyManager.searchItems(query: query)
                    self.selectedIndex = -1
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Selection Actions

    func moveSelection(by delta: Int) {
        guard !filteredItems.isEmpty else { return }

        if selectedIndex < 0 {
            selectedIndex = delta > 0 ? 0 : filteredItems.count - 1
        } else {
            let newIndex = selectedIndex + delta
            if newIndex >= 0 && newIndex < filteredItems.count {
                selectedIndex = newIndex
            }
        }
    }

    func adjustSelectionAfterItemsChange() {
        if selectedIndex >= filteredDecorators.count {
            selectedIndex = max(0, filteredDecorators.count - 1)
        }
    }

    /// Cleans up all decorator images to free memory (call when panel closes)
    func cleanupAllDecoratorImages() {
        for decorator in decoratorCache.values {
            decorator.cleanupImages()
        }
    }

    // MARK: - Clipboard Actions

    func copyToClipboard(_ item: ClipboardItem) {
        // Use PasteHelper for multi-format support
        PasteHelper.writeToClipboard(
            item: item,
            pasteboard: NSPasteboard.general,
            asPlainText: false
        )
        historyManager.moveToTop(item)
    }

    func pasteItem(_ item: ClipboardItem, asPlainText: Bool, onDismiss: () -> Void) {
        print("📋 Pasting item: \(item.previewText.prefix(50))... (plainText: \(asPlainText))")

        PasteHelper.writeToClipboard(
            item: item,
            pasteboard: NSPasteboard.general,
            asPlainText: asPlainText
        )

        historyManager.moveToTop(item)
        selectedIndex = 0
        onDismiss()
        simulatePaste()
    }

    func pasteSelectedItem(asPlainText: Bool, onDismiss: () -> Void) {
        guard selectedIndex >= 0, selectedIndex < filteredItems.count else { return }
        pasteItem(filteredItems[selectedIndex], asPlainText: asPlainText, onDismiss: onDismiss)
    }

    func pasteItemAtIndex(_ index: Int, asPlainText: Bool, onDismiss: () -> Void) {
        guard index >= 0, index < filteredItems.count else { return }
        selectedIndex = index
        pasteItem(filteredItems[index], asPlainText: asPlainText, onDismiss: onDismiss)
    }

    private func simulatePaste() {
        guard AccessibilityHelper.hasPermission else {
            print("⚠️ Paste failed: No accessibility permission")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.pasteSimulationDelay) {
            let cmdFlag = CGEventFlags(rawValue: UInt64(CGEventFlags.maskCommand.rawValue) | 0x000008)

            let source = CGEventSource(stateID: .combinedSessionState)
            source?.setLocalEventsFilterDuringSuppressionState(
                [.permitLocalMouseEvents, .permitSystemDefinedEvents],
                state: .eventSuppressionStateSuppressionInterval
            )

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: Constants.vKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: Constants.vKeyCode, keyDown: false)
            keyDown?.flags = cmdFlag
            keyUp?.flags = cmdFlag
            keyDown?.post(tap: .cgSessionEventTap)
            keyUp?.post(tap: .cgSessionEventTap)

            print("✅ Paste event posted successfully")
        }
    }

    // MARK: - Delete Actions

    func deleteSelectedItem() {
        guard selectedIndex >= 0, selectedIndex < filteredItems.count else { return }

        let item = filteredItems[selectedIndex]
        suppressScrollToTop = true
        historyManager.deleteItem(item)
    }

    // MARK: - Item Tap Handler

    func handleItemTap(at index: Int, onDismiss: () -> Void) {
        selectedIndex = index
        let item = filteredItems[index]

        if settings.pasteAutomatically {
            pasteItem(item, asPlainText: settings.plainTextMode, onDismiss: onDismiss)
        } else {
            copyToClipboard(item)
            onDismiss()
        }
    }

    // MARK: - Panel Events

    func onPanelShow() {
        if !searchText.isEmpty {
            historyManager.searchItems(query: searchText)
        }
    }

    func clearError() {
        historyManager.lastError = nil
    }
}
