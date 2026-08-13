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

    // Cached metadata (no data load needed)
    let totalSizeBytes: Int64
    let contentType: String
    let createdAt: Date
    let isPinned: Bool
    let textContent: String?
    let displayText: String
    let previewText: String
    let itemType: ClipboardItemType
    let fileURLs: [URL]?

    init(item: ClipboardItem) {
        self.id = item.id
        self.item = item
        self.totalSizeBytes = item.totalSizeBytes
        self.contentType = item.contentType
        self.createdAt = item.createdAt
        self.isPinned = item.isPinned
        self.textContent = item.textContent
        self.displayText = item.displayText
        self.previewText = item.previewText
        self.itemType = item.itemType
        self.fileURLs = item.fileURLs
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

    /// Read live from the item rather than cached at init: decorators are reused
    /// across refreshes, so a lifetime the user just picked has to show up without
    /// waiting for the decorator to be rebuilt.
    var expiresAt: Date? {
        item.expiresAt
    }

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
