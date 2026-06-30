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
            if !writeMultiFormatContents(item.contents, to: pasteboard) {
                // Fallback for legacy items without multi-format content
                if let imageData = item.imageData {
                    pasteboard.setData(imageData, forType: .png)
                }
            }

        case .file:
            if let urls = item.fileURLs {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }

        // Add Pesto marker so ClipboardMonitor ignores this paste
        addPestoMarker(to: pasteboard)
    }

    /// Replaces the pasteboard contents with plain text only, stripping all formatting.
    /// Used by plaintext mode to rewrite the live clipboard at capture time. Adds the Pesto
    /// marker so ClipboardMonitor ignores the resulting change (no capture loop).
    static func writePlainText(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        addPestoMarker(to: pasteboard)
    }

    /// Adds the Pesto source marker to the pasteboard
    /// This allows ClipboardMonitor to detect and ignore clipboard changes from Pesto itself
    private static func addPestoMarker(to pasteboard: NSPasteboard) {
        pasteboard.setData(Data(), forType: ClipboardMonitor.pestoPasteboardType)
    }

    /// Writes all stored content formats to the pasteboard, preserving original order.
    /// Uses declareTypes to ensure all formats are available to receiving apps.
    /// - Returns: true if contents were written, false if contents was nil or empty
    private static func writeMultiFormatContents(
        _ contents: Set<ClipboardItemContent>?,
        to pasteboard: NSPasteboard
    ) -> Bool {
        guard let contents = contents, !contents.isEmpty else { return false }

        // Sort by original order (preserves source app's preferred format order)
        let sortedContents = contents.sorted { $0.order < $1.order }

        // Declare all types first (including Pesto marker), then set data
        var types = sortedContents.compactMap { $0.value != nil ? $0.pasteboardType : nil }
        types.append(ClipboardMonitor.pestoPasteboardType)
        pasteboard.declareTypes(types, owner: nil)

        for content in sortedContents {
            if let data = content.value {
                pasteboard.setData(data, forType: content.pasteboardType)
            }
        }

        return true
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
