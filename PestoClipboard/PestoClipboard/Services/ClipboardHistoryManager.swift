import CoreData
import CryptoKit
import AppKit
import Combine

// MARK: - Protocol

protocol ClipboardHistoryManaging: AnyObject {
    var items: [ClipboardItem] { get }

    func fetchItems()
    func searchItems(query: String)
    func addTextItem(_ text: String, rtfData: Data?)
    func addImageItem(imageData: Data, thumbnailData: Data?)
    func addFileItem(urls: [URL])
    func moveToTop(_ item: ClipboardItem)
    func togglePin(_ item: ClipboardItem)
    func updateTextContent(_ item: ClipboardItem, newText: String)
    func deleteItem(_ item: ClipboardItem)
    func deleteItems(at offsets: IndexSet)
    func clearAll()
    func clearAllIncludingStarred()
}

// MARK: - Implementation

class ClipboardHistoryManager: ObservableObject, ClipboardHistoryManaging {
    static let shared = ClipboardHistoryManager()

    private let persistenceController: PersistenceController
    private let maxItems: Int

    @Published var items: [ClipboardItem] = []
    @Published var lastError: ClipboardError?

    enum ClipboardError: LocalizedError {
        case fetchFailed(Error)
        case saveFailed(Error)
        case searchFailed(Error)

        var errorDescription: String? {
            switch self {
            case .fetchFailed:
                return String(localized: "Failed to load clipboard history")
            case .saveFailed:
                return String(localized: "Failed to save clipboard item")
            case .searchFailed:
                return String(localized: "Failed to search clipboard history")
            }
        }

        var recoverySuggestion: String? {
            String(localized: "Try restarting the app. If the problem persists, your clipboard data may need to be reset.")
        }
    }

    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    init(persistenceController: PersistenceController = .shared, maxItems: Int = Constants.defaultHistoryLimit) {
        self.persistenceController = persistenceController
        self.maxItems = maxItems
        fetchItems()
    }

    // MARK: - Fetch

    func fetchItems() {
        let request = ClipboardItem.allItemsFetchRequest()
        do {
            items = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch clipboard items: \(error)")
            lastError = .fetchFailed(error)
        }
    }

    func searchItems(query: String) {
        let request = ClipboardItem.searchFetchRequest(query: query)
        do {
            items = try viewContext.fetch(request)
        } catch {
            print("Failed to search clipboard items: \(error)")
            lastError = .searchFailed(error)
        }
    }

    // MARK: - Add Item

    func addTextItem(_ text: String, rtfData: Data? = nil) {
        let hash = computeHash(for: text)

        // Check for duplicate
        if let existingItem = findItem(byHash: hash) {
            moveToTop(existingItem)
            return
        }

        let itemType: ClipboardItemType = rtfData != nil ? .rtf : .text
        let item = ClipboardItem.create(
            in: viewContext,
            type: itemType,
            textContent: text,
            rtfData: rtfData,
            contentHash: hash
        )

        saveAndRefresh()
        pruneIfNeeded()
    }

    func addImageItem(imageData: Data, thumbnailData: Data?) {
        let hash = computeHash(for: imageData)

        // Check for duplicate
        if let existingItem = findItem(byHash: hash) {
            moveToTop(existingItem)
            return
        }

        // Limit image size
        let storedImageData = imageData.count <= Constants.maxImageSizeBytes ? imageData : nil

        let item = ClipboardItem.create(
            in: viewContext,
            type: .image,
            imageData: storedImageData,
            thumbnailData: thumbnailData,
            contentHash: hash
        )

        saveAndRefresh()
        pruneIfNeeded()
    }

    func addFileItem(urls: [URL]) {
        let urlStrings = urls.map { $0.absoluteString }.sorted()
        let combined = urlStrings.joined(separator: "\n")
        let hash = computeHash(for: combined)

        // Check for duplicate
        if let existingItem = findItem(byHash: hash) {
            moveToTop(existingItem)
            return
        }

        let item = ClipboardItem.create(
            in: viewContext,
            type: .file,
            fileURLs: urls,
            contentHash: hash
        )

        saveAndRefresh()
        pruneIfNeeded()
    }

    // MARK: - Update

    func moveToTop(_ item: ClipboardItem) {
        item.createdAt = Date()
        saveAndRefresh()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        saveAndRefresh()
    }

    func updateTextContent(_ item: ClipboardItem, newText: String) {
        item.textContent = newText
        item.contentHash = computeHash(for: newText)
        item.createdAt = Date()
        saveAndRefresh()
    }

    // MARK: - Delete

    func deleteItem(_ item: ClipboardItem) {
        viewContext.delete(item)
        saveAndRefresh()
    }

    func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            viewContext.delete(items[index])
        }
        saveAndRefresh()
    }

    func clearAll() {
        for item in items where !item.isPinned {
            viewContext.delete(item)
        }
        saveAndRefresh()
    }

    func clearAllIncludingStarred() {
        for item in items {
            viewContext.delete(item)
        }
        saveAndRefresh()
    }

    // MARK: - Private Helpers

    private func findItem(byHash hash: String) -> ClipboardItem? {
        let request = ClipboardItem.fetchRequest(byHash: hash)
        return try? viewContext.fetch(request).first
    }

    private func saveAndRefresh() {
        do {
            try viewContext.save()
            fetchItems()
        } catch {
            print("Failed to save context: \(error)")
            lastError = .saveFailed(error)
        }
    }

    private func pruneIfNeeded() {
        // Count unpinned items
        let unpinnedItems = items.filter { !$0.isPinned }

        if unpinnedItems.count > maxItems {
            // Delete oldest unpinned items
            let itemsToDelete = unpinnedItems.suffix(unpinnedItems.count - maxItems)
            for item in itemsToDelete {
                viewContext.delete(item)
            }
            saveAndRefresh()
        }
    }

    private func computeHash(for string: String) -> String {
        let data = Data(string.utf8)
        return computeHash(for: data)
    }

    private func computeHash(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
