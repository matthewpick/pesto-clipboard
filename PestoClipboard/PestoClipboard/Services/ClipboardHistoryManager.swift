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
    func addImageItem(contents: [ClipboardMonitor.PasteboardContent], thumbnailData: Data?)
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
    private let maxItemsOverride: Int?
    private var cancellables = Set<AnyCancellable>()
    private var autoDeleteTimer: Timer?

    private var maxItems: Int {
        maxItemsOverride ?? SettingsManager.shared.historyLimit
    }

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

    init(persistenceController: PersistenceController = .shared, maxItems: Int? = nil) {
        self.persistenceController = persistenceController
        self.maxItemsOverride = maxItems
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

        // No size limit - Core Data external storage handles large blobs
        let item = ClipboardItem.create(
            in: viewContext,
            type: .image,
            imageData: imageData,
            thumbnailData: thumbnailData,
            contentHash: hash
        )
        item.totalSizeBytes = Int64(imageData.count)

        saveAndRefresh()
        pruneIfNeeded()
    }

    func addImageItem(contents: [ClipboardMonitor.PasteboardContent], thumbnailData: Data?) {
        guard !contents.isEmpty else { return }

        // Compute hash from all content data combined for duplicate detection
        let combinedData = contents.reduce(Data()) { $0 + $1.data }
        let hash = computeHash(for: combinedData)

        // Check for duplicate
        if let existingItem = findItem(byHash: hash) {
            moveToTop(existingItem)
            return
        }

        // Store primary image data (prefer PNG/TIFF for backward compatibility)
        let primaryData = contents.first { $0.type == NSPasteboard.PasteboardType.png.rawValue }?.data
            ?? contents.first { $0.type == NSPasteboard.PasteboardType.tiff.rawValue }?.data
            ?? contents.first?.data

        let item = ClipboardItem.create(
            in: viewContext,
            type: .image,
            imageData: primaryData,
            thumbnailData: thumbnailData,
            contentHash: hash
        )

        // Calculate total size
        let totalSize = contents.reduce(0) { $0 + $1.data.count }
        item.totalSizeBytes = Int64(totalSize)

        // Store all formats in the contents relationship (preserving original order)
        for (index, content) in contents.enumerated() {
            let _ = ClipboardItemContent.create(
                in: viewContext,
                type: content.type,
                value: content.data,
                order: Int16(index),
                item: item
            )
        }

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

        // The edit UI is a plain-text editor, so there is no formatting to carry over.
        // Dropping the old RTF (and demoting the type) keeps the item self-consistent:
        // leaving it in place would make the row render — and any rich-text app paste —
        // the pre-edit text, since both prefer RTF over the plain string.
        item.rtfData = nil
        if item.itemType == .rtf {
            item.contentType = ClipboardItemType.text.rawValue
        }

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

    /// Deletes every unpinned item in the store.
    ///
    /// Fetches rather than iterating `items`: that array holds whatever the UI is
    /// currently showing, which is narrowed to the matches while a search is active.
    /// Clearing only the visible subset would silently leave the rest behind.
    func clearAll() {
        deleteAll(predicate: NSPredicate(format: "isPinned == NO"))
    }

    func clearAllIncludingStarred() {
        deleteAll(predicate: nil)
    }

    private func deleteAll(predicate: NSPredicate?) {
        let request = ClipboardItem.fetchRequest()
        request.predicate = predicate

        do {
            for item in try viewContext.fetch(request) {
                viewContext.delete(item)
            }
        } catch {
            print("Failed to fetch items to clear: \(error)")
            lastError = .fetchFailed(error)
            return
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

    /// Enforces the current history limit by pruning excess items
    func enforceHistoryLimit() {
        pruneIfNeeded()
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

    // MARK: - Auto-Delete

    func startAutoDeleteTimer() {
        stopAutoDeleteTimer()

        // Subscribe to setting changes to trigger immediate cleanup
        SettingsManager.shared.$autoDeleteInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.performAutoDeleteIfEnabled()
            }
            .store(in: &cancellables)

        // Run immediately on start
        performAutoDeleteIfEnabled()

        // Schedule timer to run every 5 minutes
        autoDeleteTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.performAutoDeleteIfEnabled()
        }
    }

    func stopAutoDeleteTimer() {
        autoDeleteTimer?.invalidate()
        autoDeleteTimer = nil
    }

    private func performAutoDeleteIfEnabled() {
        guard let interval = SettingsManager.shared.autoDeleteInterval.timeInterval else {
            return
        }
        deleteExpiredItems(olderThan: interval)
    }

    func deleteExpiredItems(olderThan interval: TimeInterval) {
        let cutoffDate = Date().addingTimeInterval(-interval)

        let request = ClipboardItem.fetchRequest() as NSFetchRequest<ClipboardItem>
        request.predicate = NSPredicate(format: "isPinned == NO AND createdAt < %@", cutoffDate as NSDate)

        do {
            let expiredItems = try viewContext.fetch(request)
            for item in expiredItems {
                viewContext.delete(item)
            }
            if !expiredItems.isEmpty {
                try viewContext.save()
                fetchItems()
            }
        } catch {
            print("Failed to delete expired items: \(error)")
        }
    }
}
