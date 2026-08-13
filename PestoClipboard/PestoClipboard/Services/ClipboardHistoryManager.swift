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
    func setExpiration(_ option: ExpirationOption, for item: ClipboardItem)
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
    private var expirationTimer: Timer?

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
        // Copying a temporary item again gives it its full lifetime back.
        item.rearmExpirationIfNeeded()
        saveAndRefresh()
        scheduleNextExpirationSweep()
    }

    func togglePin(_ item: ClipboardItem) {
        item.isPinned.toggle()
        saveAndRefresh()
    }

    func updateTextContent(_ item: ClipboardItem, newText: String) {
        item.textContent = newText
        item.contentHash = computeHash(for: newText)
        item.createdAt = Date()
        item.rearmExpirationIfNeeded()
        saveAndRefresh()
        scheduleNextExpirationSweep()
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

    // MARK: - Per-Item Expiration

    /// Applies a lifetime to a single item. `.never` clears it.
    func setExpiration(_ option: ExpirationOption, for item: ClipboardItem) {
        item.applyExpiration(option)
        saveAndRefresh()
        scheduleNextExpirationSweep()
    }

    /// Deletes items whose per-item lifetime has run out.
    ///
    /// Unlike the global auto-delete, this ignores `isPinned`: the countdown was set
    /// on that specific item on purpose, so it wins over starring.
    @discardableResult
    func deleteItemsPastExpiration(asOf date: Date = Date()) -> Int {
        do {
            let expired = try viewContext.fetch(ClipboardItem.expiredItemsFetchRequest(asOf: date))
            guard !expired.isEmpty else { return 0 }

            for item in expired {
                viewContext.delete(item)
            }
            try viewContext.save()
            fetchItems()
            return expired.count
        } catch {
            print("Failed to delete items past expiration: \(error)")
            return 0
        }
    }

    /// Arms a one-shot timer for the soonest upcoming deadline, so an item disappears
    /// when it actually expires instead of waiting for the next 5-minute sweep.
    private func scheduleNextExpirationSweep() {
        expirationTimer?.invalidate()
        expirationTimer = nil

        guard let next = try? viewContext.fetch(ClipboardItem.nextExpirationFetchRequest()).first,
              let expiresAt = next.expiresAt else {
            return
        }

        // Fire slightly after the deadline so the item is unambiguously expired.
        let delay = max(expiresAt.timeIntervalSinceNow + 0.5, 1)
        expirationTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.runExpirationSweep()
        }
    }

    // MARK: - Auto-Delete

    func startAutoDeleteTimer() {
        stopAutoDeleteTimer()

        // Subscribe to setting changes to trigger immediate cleanup
        SettingsManager.shared.$autoDeleteInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.runExpirationSweep()
            }
            .store(in: &cancellables)

        // Timers don't fire while the machine is asleep, so sweep on wake as well:
        // an item that expired overnight must be gone when the screen comes back.
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak self] _ in
                self?.runExpirationSweep()
            }
            .store(in: &cancellables)

        // Run immediately on start
        runExpirationSweep()

        // Backstop sweep every 5 minutes for the global auto-delete setting
        autoDeleteTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.runExpirationSweep()
        }
    }

    func stopAutoDeleteTimer() {
        autoDeleteTimer?.invalidate()
        autoDeleteTimer = nil
        expirationTimer?.invalidate()
        expirationTimer = nil
    }

    /// Runs both cleanup policies (global auto-delete + per-item lifetimes) and
    /// re-arms the timer for the next deadline.
    private func runExpirationSweep() {
        if let interval = SettingsManager.shared.autoDeleteInterval.timeInterval {
            deleteExpiredItems(olderThan: interval)
        }
        deleteItemsPastExpiration()
        scheduleNextExpirationSweep()
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
