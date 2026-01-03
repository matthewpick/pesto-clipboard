import AppKit

/// Helper for writing clipboard items to the pasteboard
/// Extracted for testability
struct PasteHelper {

    /// Writes a clipboard item to the given pasteboard
    /// - Parameters:
    ///   - item: The clipboard item to write
    ///   - pasteboard: The pasteboard to write to
    ///   - asPlainText: If true, strips all formatting and writes plain text only
    static func writeToClipboard(
        item: ClipboardItem,
        pasteboard: NSPasteboard,
        asPlainText: Bool
    ) {
        pasteboard.clearContents()

        switch item.itemType {
        case .text, .rtf:
            if asPlainText {
                // Strip formatting and paste as plain text only
                pasteboard.setString(item.textContent ?? "", forType: .string)
            } else {
                // Preserve RTF formatting if available
                if let rtfData = item.rtfData {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
                // Always include plain text as fallback
                pasteboard.setString(item.textContent ?? "", forType: .string)
            }

        case .image:
            if let imageData = item.imageData {
                pasteboard.setData(imageData, forType: .png)
            }

        case .file:
            if let urls = item.fileURLs {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }
    }

    /// Checks if a pasteboard contains RTF data
    static func pasteboardHasRTF(_ pasteboard: NSPasteboard) -> Bool {
        return pasteboard.data(forType: .rtf) != nil
    }

    /// Checks if a pasteboard contains only plain text (no RTF)
    static func pasteboardHasOnlyPlainText(_ pasteboard: NSPasteboard) -> Bool {
        return pasteboard.string(forType: .string) != nil && pasteboard.data(forType: .rtf) == nil
    }
}
