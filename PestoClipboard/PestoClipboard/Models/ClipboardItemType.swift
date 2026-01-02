import Foundation

enum ClipboardItemType: String, CaseIterable {
    case text = "text"
    case image = "image"
    case file = "file"
    case rtf = "rtf"

    var displayName: String {
        switch self {
        case .text: return "Text"
        case .image: return "Image"
        case .file: return "File"
        case .rtf: return "Rich Text"
        }
    }

    var systemImage: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        case .rtf: return "doc.richtext"
        }
    }
}
