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
