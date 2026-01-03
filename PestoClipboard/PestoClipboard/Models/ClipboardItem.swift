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

    // MARK: - Computed Properties

    var itemType: ClipboardItemType {
        ClipboardItemType(rawValue: contentType) ?? .text
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

    static func allItemsFetchRequest() -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        return request
    }

    static func searchFetchRequest(query: String) -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ClipboardItem.createdAt, ascending: false)]
        if !query.isEmpty {
            request.predicate = NSPredicate(format: "textContent CONTAINS[cd] %@", query)
        }
        return request
    }

    static func fetchRequest(byHash hash: String) -> NSFetchRequest<ClipboardItem> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "contentHash == %@", hash)
        request.fetchLimit = 1
        return request
    }
}
