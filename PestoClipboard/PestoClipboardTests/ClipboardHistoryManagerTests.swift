import Testing
import CoreData
@testable import Pesto_Clipboard

@MainActor
struct ClipboardHistoryManagerTests {

    // MARK: - Helper

    func createManager(maxItems: Int = 500) -> ClipboardHistoryManager {
        let persistenceController = PersistenceController(inMemory: true)
        return ClipboardHistoryManager(persistenceController: persistenceController, maxItems: maxItems)
    }

    // MARK: - Add Text Item Tests

    @Test func addTextItemCreatesItem() {
        let manager = createManager()

        manager.addTextItem("Hello, World!")

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.textContent == "Hello, World!")
        #expect(manager.items.first?.itemType == .text)
    }

    @Test func addMultipleTextItems() {
        let manager = createManager()

        manager.addTextItem("First")
        manager.addTextItem("Second")
        manager.addTextItem("Third")

        #expect(manager.items.count == 3)
        // Most recent should be first (sorted by createdAt descending)
        #expect(manager.items[0].textContent == "Third")
        #expect(manager.items[1].textContent == "Second")
        #expect(manager.items[2].textContent == "First")
    }

    // MARK: - Duplicate Detection Tests

    @Test func duplicateTextItemMovesToTop() {
        let manager = createManager()

        manager.addTextItem("Duplicate")
        manager.addTextItem("Other")
        manager.addTextItem("Duplicate") // Should move to top, not create new

        #expect(manager.items.count == 2)
        #expect(manager.items[0].textContent == "Duplicate")
        #expect(manager.items[1].textContent == "Other")
    }

    @Test func differentTextCreatesNewItems() {
        let manager = createManager()

        manager.addTextItem("First")
        manager.addTextItem("Second")

        #expect(manager.items.count == 2)
    }

    // MARK: - Move to Top Tests

    @Test func moveToTopUpdatesItemOrder() {
        let manager = createManager()

        manager.addTextItem("First")
        manager.addTextItem("Second")
        manager.addTextItem("Third")

        // Move "First" to top
        if let firstItem = manager.items.last {
            manager.moveToTop(firstItem)
        }

        #expect(manager.items[0].textContent == "First")
    }

    // MARK: - Pin Tests

    @Test func togglePinPinsItem() {
        let manager = createManager()

        manager.addTextItem("Test item")
        let item = manager.items.first!

        #expect(item.isPinned == false)

        manager.togglePin(item)

        #expect(item.isPinned == true)
    }

    @Test func togglePinUnpinsItem() {
        let manager = createManager()

        manager.addTextItem("Test item")
        let item = manager.items.first!

        manager.togglePin(item) // Pin
        manager.togglePin(item) // Unpin

        #expect(item.isPinned == false)
    }

    // MARK: - Delete Tests

    @Test func deleteItemRemovesItem() {
        let manager = createManager()

        manager.addTextItem("To delete")
        manager.addTextItem("To keep")

        let itemToDelete = manager.items.last!
        manager.deleteItem(itemToDelete)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.textContent == "To keep")
    }

    @Test func clearAllRemovesUnpinnedItems() {
        let manager = createManager()

        manager.addTextItem("Unpinned 1")
        manager.addTextItem("Pinned")
        manager.addTextItem("Unpinned 2")

        // Pin the middle item
        let pinnedItem = manager.items[1]
        manager.togglePin(pinnedItem)

        manager.clearAll()

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.textContent == "Pinned")
    }

    @Test func clearAllIncludingStarredRemovesAllItems() {
        let manager = createManager()

        manager.addTextItem("Unpinned")
        manager.addTextItem("Pinned")

        // Pin one item
        let pinnedItem = manager.items.last!
        manager.togglePin(pinnedItem)

        manager.clearAllIncludingStarred()

        #expect(manager.items.count == 0)
    }

    // MARK: - Search Tests

    @Test func searchItemsFiltersResults() {
        let manager = createManager()

        manager.addTextItem("Apple pie recipe")
        manager.addTextItem("Banana bread")
        manager.addTextItem("Apple cider vinegar")

        manager.searchItems(query: "Apple")

        #expect(manager.items.count == 2)
        #expect(manager.items.allSatisfy { $0.textContent?.contains("Apple") == true })
    }

    @Test func searchItemsCaseInsensitive() {
        let manager = createManager()

        manager.addTextItem("HELLO WORLD")
        manager.addTextItem("hello there")
        manager.addTextItem("Goodbye")

        manager.searchItems(query: "hello")

        #expect(manager.items.count == 2)
    }

    @Test func fetchItemsRestoresAllItems() {
        let manager = createManager()

        manager.addTextItem("Item 1")
        manager.addTextItem("Item 2")
        manager.addTextItem("Item 3")

        manager.searchItems(query: "Item 1") // Filters to 1 item
        #expect(manager.items.count == 1)

        manager.fetchItems() // Restore all
        #expect(manager.items.count == 3)
    }

    // MARK: - Pruning Tests

    @Test func pruneIfNeededRemovesOldestItems() {
        let manager = createManager(maxItems: 3)

        manager.addTextItem("First")
        manager.addTextItem("Second")
        manager.addTextItem("Third")
        manager.addTextItem("Fourth") // Should trigger prune

        #expect(manager.items.count == 3)
        // Oldest ("First") should be removed
        #expect(manager.items.contains { $0.textContent == "First" } == false)
        #expect(manager.items.contains { $0.textContent == "Fourth" } == true)
    }

    @Test func pruneIfNeededKeepsPinnedItems() {
        let manager = createManager(maxItems: 2)

        manager.addTextItem("First - Pinned")
        manager.togglePin(manager.items.first!)

        manager.addTextItem("Second")
        manager.addTextItem("Third")
        manager.addTextItem("Fourth")

        // Pinned item should survive even though it's oldest
        #expect(manager.items.contains { $0.textContent == "First - Pinned" } == true)
        #expect(manager.items.first { $0.textContent == "First - Pinned" }?.isPinned == true)
    }

    @Test func pruneAt500LimitPreservesAllPinnedItems() {
        // Test with actual default limit of 500
        // Note: The limit applies to UNPINNED items only - pinned items are never deleted
        // Use isolated persistence controller to avoid test pollution
        let isolatedController = PersistenceController(inMemory: true)
        let manager = ClipboardHistoryManager(persistenceController: isolatedController, maxItems: 500)

        // Add 10 items and pin them at various positions
        let pinnedPositions = [1, 50, 100, 250, 400, 450, 475, 490, 499, 500]

        // Add 500 items, pinning specific ones
        for i in 1...500 {
            let text = "Item-\(String(format: "%03d", i))"
            manager.addTextItem(text)

            // Pin items at specific positions
            if pinnedPositions.contains(i) {
                if let item = manager.items.first(where: { $0.textContent == text }) {
                    manager.togglePin(item)
                }
            }
        }

        // We have 500 items total: 10 pinned + 490 unpinned
        #expect(manager.items.count == 500)
        let pinnedCount = manager.items.filter { $0.isPinned }.count
        #expect(pinnedCount == 10)
        let unpinnedCount = manager.items.filter { !$0.isPinned }.count
        #expect(unpinnedCount == 490)

        // Add 50 more items to trigger pruning
        // Unpinned count goes from 490 to 540, which exceeds 500 limit
        for i in 501...550 {
            manager.addTextItem("Item-\(String(format: "%03d", i))")
        }

        // Total count should be 10 pinned + 500 unpinned = 510
        // (Pruning keeps unpinned at maxItems, but pinned are extra)
        #expect(manager.items.count == 510)

        // All 10 pinned items MUST still exist
        let pinnedAfterPrune = manager.items.filter { $0.isPinned }
        #expect(pinnedAfterPrune.count == 10)

        // Unpinned should be exactly maxItems (500)
        let unpinnedAfterPrune = manager.items.filter { !$0.isPinned }
        #expect(unpinnedAfterPrune.count == 500)

        // Verify each pinned item survived
        for pos in pinnedPositions {
            let text = "Item-\(String(format: "%03d", pos))"
            let exists = manager.items.contains { $0.textContent == text && $0.isPinned }
            #expect(exists, "Pinned item '\(text)' should survive pruning")
        }

        // Verify newest items (501-550) exist
        for i in 501...550 {
            let text = "Item-\(String(format: "%03d", i))"
            #expect(manager.items.contains { $0.textContent == text }, "New item '\(text)' should exist")
        }

        // Verify oldest unpinned items were removed
        // Items 2-41 should be gone (40 oldest unpinned items pruned)
        // (We added 50 new items, had 490 unpinned, need to get to 500 unpinned)
        // Wait: 490 + 50 = 540 unpinned, need to remove 40 to get to 500
        for i in 2...41 {
            // Skip if this was a pinned position
            if pinnedPositions.contains(i) { continue }
            let text = "Item-\(String(format: "%03d", i))"
            #expect(manager.items.contains { $0.textContent == text } == false,
                   "Old unpinned item '\(text)' should be pruned")
        }
    }

    @Test func prunePreservesPinnedEvenWhenManyPinned() {
        // Edge case: Many pinned items - they should all survive
        // The limit only applies to unpinned items
        // Use isolated persistence controller to avoid test pollution
        let isolatedController = PersistenceController(inMemory: true)
        let manager = ClipboardHistoryManager(persistenceController: isolatedController, maxItems: 10)

        // Add 10 items
        for i in 1...10 {
            manager.addTextItem("Item-\(i)")
        }

        // Pin items 1-8
        for i in 1...8 {
            if let item = manager.items.first(where: { $0.textContent == "Item-\(i)" }) {
                manager.togglePin(item)
            }
        }

        #expect(manager.items.count == 10)
        #expect(manager.items.filter { $0.isPinned }.count == 8)

        // Add 20 more items - will trigger pruning multiple times
        for i in 11...30 {
            manager.addTextItem("Item-\(i)")
        }

        // All 8 pinned items must survive
        let pinnedItems = manager.items.filter { $0.isPinned }
        #expect(pinnedItems.count == 8, "Expected 8 pinned items, got \(pinnedItems.count)")

        // Unpinned count should be capped at maxItems (10)
        let unpinnedItems = manager.items.filter { !$0.isPinned }
        #expect(unpinnedItems.count == 10, "Expected 10 unpinned items, got \(unpinnedItems.count)")

        // Total should be 8 pinned + 10 unpinned = 18
        #expect(manager.items.count == 18, "Expected 18 total items, got \(manager.items.count)")

        // Newest items (21-30) should definitely exist
        #expect(manager.items.contains { $0.textContent == "Item-30" } == true)
        #expect(manager.items.contains { $0.textContent == "Item-21" } == true)
    }

    // MARK: - Image Item Tests

    @Test func addImageItemCreatesItem() {
        let manager = createManager()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // Fake PNG
        let thumbnailData = Data([0xFF, 0xD8, 0xFF]) // Fake JPEG

        manager.addImageItem(imageData: imageData, thumbnailData: thumbnailData)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.itemType == .image)
        #expect(manager.items.first?.imageData == imageData)
        #expect(manager.items.first?.thumbnailData == thumbnailData)
    }

    @Test func duplicateImageMovesToTop() {
        let manager = createManager()
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])

        manager.addImageItem(imageData: imageData, thumbnailData: nil)
        manager.addTextItem("Text in between")
        manager.addImageItem(imageData: imageData, thumbnailData: nil) // Duplicate

        #expect(manager.items.count == 2)
        #expect(manager.items[0].itemType == .image)
    }

    // MARK: - File Item Tests

    @Test func addFileItemCreatesItem() {
        let manager = createManager()
        let urls = [URL(fileURLWithPath: "/path/to/file.txt")]

        manager.addFileItem(urls: urls)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.itemType == .file)
        #expect(manager.items.first?.fileURLs?.count == 1)
    }

    @Test func addMultipleFilesInOneItem() {
        let manager = createManager()
        let urls = [
            URL(fileURLWithPath: "/path/file1.txt"),
            URL(fileURLWithPath: "/path/file2.txt"),
            URL(fileURLWithPath: "/path/file3.txt")
        ]

        manager.addFileItem(urls: urls)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.fileURLs?.count == 3)
    }
}
