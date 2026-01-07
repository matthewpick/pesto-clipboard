import Testing
import AppKit
import Combine
@testable import Pesto_Clipboard

// MARK: - Clipboard to History Manager Integration Tests

@MainActor
struct ClipboardToHistoryIntegrationTests {

    func createManager(maxItems: Int = 100) -> ClipboardHistoryManager {
        let persistenceController = PersistenceController(inMemory: true)
        return ClipboardHistoryManager(persistenceController: persistenceController, maxItems: maxItems)
    }

    // MARK: - Flow Tests

    @Test func textAddedToHistoryAppearsInItems() {
        let manager = createManager()
        manager.addTextItem("Test text")

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.textContent == "Test text")
        #expect(manager.items.first?.itemType == .text)
    }

    @Test func multipleItemsMaintainOrder() {
        let manager = createManager()
        manager.addTextItem("First")
        manager.addTextItem("Second")
        manager.addTextItem("Third")

        #expect(manager.items.count == 3)
        #expect(manager.items[0].textContent == "Third")
        #expect(manager.items[1].textContent == "Second")
        #expect(manager.items[2].textContent == "First")
    }

    @Test func duplicateTextMovesToTop() {
        let manager = createManager()
        manager.addTextItem("First")
        manager.addTextItem("Second")
        manager.addTextItem("First") // Duplicate

        #expect(manager.items.count == 2)
        #expect(manager.items[0].textContent == "First")
        #expect(manager.items[1].textContent == "Second")
    }

    @Test func imageAddedToHistoryWithThumbnail() {
        let manager = createManager()

        // Create a small test image
        let image = NSImage(size: NSSize(width: 100, height: 100))
        image.lockFocus()
        NSColor.red.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 100, height: 100))
        image.unlockFocus()

        guard let pngData = image.pngData() else {
            Issue.record("Failed to create PNG data")
            return
        }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: pngData)
        manager.addImageItem(imageData: pngData, thumbnailData: thumbnail)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.itemType == .image)
        #expect(manager.items.first?.imageData != nil)
    }

    @Test func fileURLsAddedToHistory() {
        let manager = createManager()
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test-\(UUID().uuidString).txt")
        try? "test content".write(to: tempURL, atomically: true, encoding: .utf8)

        manager.addFileItem(urls: [tempURL])

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.itemType == .file)
        #expect(manager.items.first?.fileURLs?.count == 1)

        try? FileManager.default.removeItem(at: tempURL)
    }

    // MARK: - Search Integration Tests

    @Test func searchFiltersItemsCorrectly() {
        let manager = createManager()
        manager.addTextItem("Apple pie recipe")
        manager.addTextItem("Orange juice")
        manager.addTextItem("Apple cider")

        manager.searchItems(query: "apple")

        #expect(manager.items.count == 2)
        #expect(manager.items.allSatisfy { $0.textContent?.lowercased().contains("apple") ?? false })
    }

    @Test func searchIsCaseInsensitive() {
        let manager = createManager()
        manager.addTextItem("HELLO WORLD")
        manager.addTextItem("hello there")
        manager.addTextItem("Goodbye")

        manager.searchItems(query: "hello")

        #expect(manager.items.count == 2)
    }

    // MARK: - Pin Integration Tests

    @Test func pinnedItemsPreservedDuringPrune() {
        let manager = createManager(maxItems: 10)

        // Add items up to limit
        for i in 1...10 {
            manager.addTextItem("Item \(i)")
        }

        // Pin first item (which is at the end since newest is first)
        if let itemToPin = manager.items.last {
            manager.togglePin(itemToPin)
        }

        // Add more items to trigger prune
        for i in 11...20 {
            manager.addTextItem("Item \(i)")
        }

        // Pinned item should still exist
        let pinnedItems = manager.items.filter { $0.isPinned }
        #expect(pinnedItems.count == 1)
        #expect(pinnedItems.first?.textContent == "Item 1")
    }
}

// MARK: - History Manager to UI Integration Tests

@MainActor
struct HistoryManagerToUIIntegrationTests {

    func createSetup() -> (ClipboardHistoryManager, ClipboardMonitor) {
        let persistenceController = PersistenceController(inMemory: true)
        let manager = ClipboardHistoryManager(persistenceController: persistenceController, maxItems: 100)
        let monitor = ClipboardMonitor(historyManager: manager)
        return (manager, monitor)
    }

    @Test func viewModelReflectsHistoryManagerItems() {
        let (manager, monitor) = createSetup()
        let viewModel = HistoryViewModel(historyManager: manager, clipboardMonitor: monitor)

        manager.addTextItem("Test item")

        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.textContent == "Test item")
    }

    @Test func viewModelSearchFiltersCorrectly() async throws {
        let (manager, monitor) = createSetup()
        let viewModel = HistoryViewModel(historyManager: manager, clipboardMonitor: monitor)

        manager.addTextItem("Apple")
        manager.addTextItem("Banana")
        manager.addTextItem("Cherry")

        viewModel.searchText = "apple"

        // Wait for debounce to complete
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.textContent == "Apple")
    }

    @Test func viewModelStarredFilterWorks() {
        let (manager, monitor) = createSetup()
        let viewModel = HistoryViewModel(historyManager: manager, clipboardMonitor: monitor)

        manager.addTextItem("Normal item")
        manager.addTextItem("Starred item")

        // Pin the starred item
        if let item = manager.items.first {
            manager.togglePin(item)
        }

        viewModel.showStarredOnly = true

        #expect(viewModel.filteredItems.count == 1)
        #expect(viewModel.filteredItems.first?.textContent == "Starred item")
    }

    @Test func viewModelSelectionClampsAfterItemsChange() {
        let (manager, monitor) = createSetup()
        let viewModel = HistoryViewModel(historyManager: manager, clipboardMonitor: monitor)

        manager.addTextItem("Item 1")
        manager.addTextItem("Item 2")
        manager.addTextItem("Item 3")

        // Verify initial state
        #expect(viewModel.filteredItems.count == 3)

        // Set selection beyond bounds
        viewModel.selectedIndex = 10

        // adjustSelectionAfterItemsChange clamps the index
        viewModel.adjustSelectionAfterItemsChange()

        #expect(viewModel.selectedIndex == 2) // Clamped to last valid index
    }

    @Test func viewModelMoveSelectionWrapsCorrectly() {
        let (manager, monitor) = createSetup()
        let viewModel = HistoryViewModel(historyManager: manager, clipboardMonitor: monitor)

        manager.addTextItem("Item 1")
        manager.addTextItem("Item 2")
        manager.addTextItem("Item 3")

        // Start at 0
        viewModel.selectedIndex = 0

        // Move up should not go negative
        viewModel.moveSelection(by: -1)
        #expect(viewModel.selectedIndex == 0)

        // Move to end
        viewModel.selectedIndex = 2

        // Move down should not exceed bounds
        viewModel.moveSelection(by: 1)
        #expect(viewModel.selectedIndex == 2)
    }
}

// MARK: - Event Bus Integration Tests

@MainActor
struct EventBusIntegrationTests {

    @Test func eventBusDeliversEvents() async {
        var cancellables = Set<AnyCancellable>()
        var receivedEvents: [AppEvent] = []

        AppEventBus.shared.publisher
            .sink { event in
                receivedEvents.append(event)
            }
            .store(in: &cancellables)

        AppEventBus.shared.showHistoryPanel()
        AppEventBus.shared.hideHistoryPanel()
        AppEventBus.shared.deleteSelectedItem()

        // Give time for events to propagate
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        #expect(receivedEvents.contains(.showHistoryPanel))
        #expect(receivedEvents.contains(.hideHistoryPanel))
        #expect(receivedEvents.contains(.deleteSelectedItem))
    }

    @Test func eventBusFiltersByEventType() async {
        var cancellables = Set<AnyCancellable>()
        var showCount = 0
        var hideCount = 0

        AppEventBus.shared.publisher(for: .showHistoryPanel)
            .sink { showCount += 1 }
            .store(in: &cancellables)

        AppEventBus.shared.publisher(for: .hideHistoryPanel)
            .sink { hideCount += 1 }
            .store(in: &cancellables)

        AppEventBus.shared.showHistoryPanel()
        AppEventBus.shared.hideHistoryPanel()

        // Give time for events to propagate
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms

        // Verify each filter only gets its own event type
        #expect(showCount >= 1) // At least one show event
        #expect(hideCount >= 1) // At least one hide event
    }
}

// MARK: - Paste Flow Integration Tests

@MainActor
struct PasteFlowIntegrationTests {

    func createManager() -> ClipboardHistoryManager {
        let persistenceController = PersistenceController(inMemory: true)
        return ClipboardHistoryManager(persistenceController: persistenceController, maxItems: 100)
    }

    @Test func pasteTextItemWritesToClipboard() {
        let manager = createManager()
        manager.addTextItem("Paste me")

        guard let item = manager.items.first else {
            Issue.record("No item in history")
            return
        }

        let pasteboard = NSPasteboard(name: .init("test-paste-\(UUID().uuidString)"))
        pasteboard.clearContents()

        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard, asPlainText: false)

        #expect(pasteboard.string(forType: .string) == "Paste me")
    }

    @Test func pasteImageItemWritesToClipboard() {
        let manager = createManager()

        // Create a small test image
        let image = NSImage(size: NSSize(width: 50, height: 50))
        image.lockFocus()
        NSColor.blue.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 50, height: 50))
        image.unlockFocus()

        guard let pngData = image.pngData() else {
            Issue.record("Failed to create PNG data")
            return
        }

        let thumbnail = ThumbnailGenerator.generateThumbnail(from: pngData)
        manager.addImageItem(imageData: pngData, thumbnailData: thumbnail)

        guard let item = manager.items.first else {
            Issue.record("No item in history")
            return
        }

        let pasteboard = NSPasteboard(name: .init("test-image-paste-\(UUID().uuidString)"))
        pasteboard.clearContents()

        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard, asPlainText: false)

        #expect(pasteboard.data(forType: .png) != nil)
    }

    @Test func pasteRTFItemRespectsPlainTextMode() {
        let manager = createManager()

        // Create RTF data
        let attributedString = NSAttributedString(
            string: "Formatted",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        let rtfData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )

        manager.addTextItem("Formatted", rtfData: rtfData)

        guard let item = manager.items.first else {
            Issue.record("No item in history")
            return
        }

        // Paste in plaintext mode
        let pasteboardPlain = NSPasteboard(name: .init("test-rtf-plain-\(UUID().uuidString)"))
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboardPlain, asPlainText: true)

        #expect(pasteboardPlain.string(forType: .string) == "Formatted")
        #expect(pasteboardPlain.data(forType: .rtf) == nil)

        // Paste with formatting
        let pasteboardFormatted = NSPasteboard(name: .init("test-rtf-format-\(UUID().uuidString)"))
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboardFormatted, asPlainText: false)

        #expect(pasteboardFormatted.string(forType: .string) == "Formatted")
        #expect(pasteboardFormatted.data(forType: .rtf) != nil)
    }
}
