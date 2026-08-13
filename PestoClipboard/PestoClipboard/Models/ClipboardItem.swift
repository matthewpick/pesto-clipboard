import CoreData
import AppKit

@objc(ClipboardItem)
public class ClipboardItem: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var contentType: String
    @NSManaged public var contentHash: String
    @NSManaged public var textContent: String?
    @NSManaged public var rtfData: Data?
    @NSManaged public var imageData: Data?
    @NSManaged public var thumbnailData: Data?
    @NSManaged public var fileURLsData: Data?
    @NSManaged public var isPinned: Bool
    @NSManaged public var totalSizeBytes: Int64
    @NSManaged public var expiresAt: Date?
    @NSManaged public var expirationDuration: Double
    @NSManaged public var contents: Set<ClipboardItemContent>?

    // MARK: - Computed Properties

    var itemType: ClipboardItemType {
        ClipboardItemType(rawValue: contentType) ?? .text
    }

    // MARK: - Expiration

    /// The lifetime preset currently applied to this item.
    var expirationOption: ExpirationOption {
        ExpirationOption(duration: expirationDuration)
    }

    var hasExpiration: Bool {
        expiresAt != nil
    }

    func isExpired(asOf date: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= date
    }

    /// Starts (or restarts) the countdown from `date`. Passing `.never` clears it.
    func applyExpiration(_ option: ExpirationOption, from date: Date = Date()) {
        guard let duration = option.duration else {
            expirationDuration = 0
            expiresAt = nil
            return
        }
        expirationDuration = duration
        expiresAt = date.addingTimeInterval(duration)
    }

    /// Restarts the countdown from `date` if a lifetime is set. Called when an item
    /// is copied again so re-using a temporary item gives it its full lifetime back.
    func rearmExpirationIfNeeded(from date: Date = Date()) {
        guard expirationDuration > 0 else { return }
        expiresAt = date.addingTimeInterval(expirationDuration)
    }

    var fileURLs: [URL]? {
        get {
            guard let data = fileURLsData else { return nil }
            return try? JSONDecoder().decode([URL].self, from: data)
        }
        set {
            fileURLsData = try? JSONEncoder().encode(newValue)
        }
    }

    var thumbnailImage: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }

    var fullImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var attributedString: NSAttributedString? {
        guard let data = rtfData else { return nil }
        return NSAttributedString(rtf: data, documentAttributes: nil)
    }

    var displayText: String {
        switch itemType {
        case .text, .rtf:
            return textContent ?? ""
        case .image:
            return "Image"
        case .file:
            if let urls = fileURLs {
                if urls.count == 1 {
                    return urls[0].lastPathComponent
                } else {
                    return "\(urls.count) files"
                }
            }
            return "File"
        }
    }

    var previewText: String {
        let text = displayText
        let maxLength = 200
        if text.count > maxLength {
            return String(text.prefix(maxLength)) + "..."
        }
        return text
    }

    // MARK: - Factory Methods

    static func create(
        in context: NSManagedObjectContext,
        type: ClipboardItemType,
        textContent: String? = nil,
        rtfData: Data? = nil,
        imageData: Data? = nil,
        thumbnailData: Data? = nil,
        fileURLs: [URL]? = nil,
        contentHash: String
    ) -> ClipboardItem {
        let item = ClipboardItem(context: context)
        item.id = UUID()
        item.createdAt = Date()
        item.contentType = type.rawValue
        item.contentHash = contentHash
        item.textContent = textContent
        item.rtfData = rtfData
        item.imageData = imageData
        item.thumbnailData = thumbnailData
        item.fileURLs = fileURLs
        item.isPinned = false
        return item
    }
}

// MARK: - Fetch Requests

extension ClipboardItem {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ClipboardItem> {
        return NSFetchRequest<ClipboardItem>(entityName: "ClipboardItem")
    }

    /// Matches items whose per-item lifetime has not run out yet. Expired rows are
    /// filtered out of every list fetch so a stale item can never be shown between
    /// the moment it expires and the moment the sweep deletes it (after a long
    /// sleep, for instance).
    static func unexpiredPredicate(asOf date: Date = Date()) -> NSPredicate {
        NSPredicate(format: "expiresAt == nil OR expiresAt > %@", date as NSDate)
    }

    static func allItemsFetchRequest() -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        request.predicate = unexpiredPredicate()
        return request
    }

    static func searchFetchRequest(query: String) -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        if query.isEmpty {
            request.predicate = unexpiredPredicate()
        } else {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "textContent CONTAINS[cd] %@", query),
                unexpiredPredicate()
            ])
        }
        return request
    }

    /// Items whose lifetime has run out and that are ready to be deleted.
    static func expiredItemsFetchRequest(asOf date: Date = Date()) -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "expiresAt != nil AND expiresAt <= %@", date as NSDate)
        return request
    }

    /// The soonest deadline still in the future, used to schedule the sweep timer.
    static func nextExpirationFetchRequest(after date: Date = Date()) -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "expiresAt != nil AND expiresAt > %@", date as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.expiresAt, ascending: true)]
        request.fetchLimit = 1
        return request
    }

    static func fetchRequest(byHash hash: String) -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1
        return request
    }
}
