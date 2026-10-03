import AppKit
import Combine

/// Decorator for ClipboardItem that provides lazy loading of binary data (images, thumbnails).
/// Used in the UI layer to avoid loading all clipboard item data into memory at once.
@MainActor
class ClipboardItemDecorator: ObservableObject, Identifiable, Hashable {
    let id: UUID
    let item: ClipboardItem

    // Lazy-loaded thumbnail (not loaded until visible)
    @Published private(set) var thumbnailImage: NSImage?

    // Track visibility state for memory management
    var isVisible: Bool = false

    // Task for async thumbnail loading
    private var thumbnailTask: Task<Void, Never>?

    // Cleanup delay to avoid thrashing when scrolling fast
    private static let cleanupDelay: TimeInterval = 2.0

    // Immutable metadata, cached at init. These are fixed when the item is created
    // and never mutated afterwards, so caching them avoids repeated work in the list
    // (notably `fileURLs`, which decodes JSON on every read).
    let totalSizeBytes: Int64
    let contentType: String
    let itemType: ClipboardItemType
    let fileURLs: [URL]?

    // Mutable metadata, read live from the managed object. Decorators are cached and
    // reused by HistoryViewModel for as long as their item exists, so anything the
    // app can change after creation — starring, editing, moving an item to the top —
    // must NOT be snapshotted here or the row would render a stale value forever.
    // These are cheap scalar reads on an already-faulted row; the expensive binary
    // blobs stay lazy below.
    var isPinned: Bool { item.isPinned }
    var createdAt: Date { item.createdAt }
    var textContent: String? { item.textContent }
    var displayText: String { item.displayText }
    var previewText: String { item.previewText }

    init(item: ClipboardItem) {
        self.id = item.id
        self.item = item
        self.totalSizeBytes = item.totalSizeBytes
        self.contentType = item.contentType
        self.itemType = item.itemType
        self.fileURLs = item.fileURLs
    }

    /// Notifies observing rows that the underlying item's mutable metadata changed.
    /// Called by HistoryViewModel after a save, since the values above are read live
    /// and so publish nothing on their own.
    func refreshMetadata() {
        objectWillChange.send()
    }

    // MARK: - Lazy Loading

    /// Call when the row appears in the visible area.
    /// Triggers async thumbnail loading if not already loaded.
    func ensureThumbnailImage() {
        guard thumbnailImage == nil, thumbnailTask == nil else { return }

        thumbnailTask = Task { @MainActor in
            // Load thumbnail from Core Data (this triggers faulting only for thumbnailData)
            if let data = item.thumbnailData {
                thumbnailImage = NSImage(data: data)
            }
            thumbnailTask = nil
        }
    }

    /// Call when the row disappears from the visible area (with delay).
    /// Releases thumbnail image from memory after a delay to prevent thrashing during fast scrolling.
    func cleanupImages() {
        // Cancel any pending load
        thumbnailTask?.cancel()
        thumbnailTask = nil

        // Clear the cached image to free memory
        thumbnailImage = nil
    }

    // MARK: - Passthrough Properties

    /// Returns the attributed string for RTF content (loads from Core Data on-demand)
    var attributedString: NSAttributedString? {
        item.attributedString
    }

    /// Returns the full image data (loads from Core Data on-demand)
    /// Use sparingly - prefer thumbnailImage for list display
    var fullImageData: Data? {
        item.imageData
    }

    /// Returns the full image (loads from Core Data on-demand)
    /// Use sparingly - prefer thumbnailImage for list display
    var fullImage: NSImage? {
        item.fullImage
    }

    // MARK: - Hashable

    static func == (lhs: ClipboardItemDecorator, rhs: ClipboardItemDecorator) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Array Extension for Decorator Wrapping

extension Array where Element == ClipboardItem {
    /// Wraps each ClipboardItem in a decorator for lazy loading
    @MainActor
    func asDecorators() -> [ClipboardItemDecorator] {
        map { ClipboardItemDecorator(item: $0) }
    }
}
