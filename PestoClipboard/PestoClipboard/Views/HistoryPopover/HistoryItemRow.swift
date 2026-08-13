import SwiftUI
import UniformTypeIdentifiers

struct HistoryItemRow: View {
    @ObservedObject var decorator: ClipboardItemDecorator
    let index: Int
    let isSelected: Bool
    var onToggleStar: () -> Void = {}

    @State private var isHovered: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Star indicator (always visible, vertically centered)
            Button {
                onToggleStar()
            } label: {
                Image(systemName: decorator.isPinned ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(decorator.isPinned ? .yellow : .secondary.opacity(0.4))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content preview
            contentPreview

            Spacer(minLength: 4)

            // Countdown for items with their own expiration
            if let expiresAt = decorator.expiresAt {
                expirationBadge(expiresAt)
            }

            // Index number for keyboard shortcut (1-9)
            if index <= 9 {
                Text("\(index)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .onDrag {
            createItemProvider()
        }
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Expiration

    /// Countdown shown on items that carry their own lifetime. `.relative` keeps the
    /// text current on its own, so the list doesn't need a per-row ticking timer.
    private func expirationBadge(_ expiresAt: Date) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "clock")
            Text(expiresAt, style: .relative)
        }
        .font(.system(size: 10))
        .foregroundStyle(.secondary)
        .fixedSize()
        .help(Text("Expires \(expiresAt.formatted(date: .abbreviated, time: .shortened))"))
    }

    // MARK: - Drag and Drop

    private func createItemProvider() -> NSItemProvider {
        switch decorator.itemType {
        case .text:
            // Plain text
            if let text = decorator.textContent {
                return NSItemProvider(object: text as NSString)
            }

        case .rtf:
            // Rich text - provide both RTF and plain text
            let provider = NSItemProvider()
            if let rtfData = decorator.item.rtfData {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.rtf.identifier, visibility: .all) { completion in
                    completion(rtfData, nil)
                    return nil
                }
            }
            if let text = decorator.textContent {
                provider.registerObject(text as NSString, visibility: .all)
            }
            return provider

        case .image:
            // Image data - use full image for drag
            if let imageData = decorator.fullImageData, let nsImage = NSImage(data: imageData) {
                return NSItemProvider(object: nsImage)
            }

        case .file:
            // File URLs
            if let urls = decorator.fileURLs, let firstURL = urls.first {
                return NSItemProvider(object: firstURL as NSURL)
            }
        }

        // Fallback
        return NSItemProvider()
    }

    private var backgroundColor: Color {
        if isHovered && !isSelected {
            return Color.primary.opacity(0.08)
        } else {
            return Color.clear
        }
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch decorator.itemType {
        case .text, .rtf:
            textPreview

        case .image:
            imagePreview

        case .file:
            filePreview
        }
    }

    private var textPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Check if it looks like a URL
            if let text = decorator.textContent, isURL(text) {
                Text(text)
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(.blue)
                    .lineLimit(2)
            } else if let nsAttributedString = decorator.attributedString {
                // Display rich text with formatting
                Text(attributedPreview(from: nsAttributedString))
                    .lineLimit(3)
            } else {
                Text(decorator.previewText)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .lineLimit(3)
            }
        }
    }

    private func attributedPreview(from nsAttributedString: NSAttributedString) -> AttributedString {
        // Truncate to reasonable preview length
        let maxLength = 200
        let length = min(nsAttributedString.length, maxLength)
        let truncated = nsAttributedString.attributedSubstring(from: NSRange(location: 0, length: length))

        // Create a mutable copy to normalize font sizes while preserving other attributes
        let mutableAttrString = NSMutableAttributedString(attributedString: truncated)
        let fullRange = NSRange(location: 0, length: mutableAttrString.length)

        // Remove background color attribute (keep foreground/text color)
        mutableAttrString.removeAttribute(.backgroundColor, range: fullRange)

        // Drop foreground colors that would be unreadable against the panel
        // background (e.g. near-black text copied from a light document shown on
        // the dark panel). Removing the attribute lets the text inherit the
        // adaptive primary color (white in dark mode, black in light mode), while
        // genuinely colored text (green paths, orange markdown) is preserved.
        mutableAttrString.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? NSColor,
               RichTextColorNormalizer.isUnreadable(color, colorScheme: colorScheme) {
                mutableAttrString.removeAttribute(.foregroundColor, range: range)
            }
        }

        // Enumerate through font attributes and normalize size while preserving traits (bold, italic)
        mutableAttrString.enumerateAttribute(.font, in: fullRange, options: []) { value, range, _ in
            if let font = value as? NSFont {
                // Get font traits (bold, italic, etc.)
                let traits = NSFontManager.shared.traits(of: font)
                // Create new font with same traits but normalized size
                var newFont = NSFont.systemFont(ofSize: 13)
                if traits.contains(.boldFontMask) && traits.contains(.italicFontMask) {
                    if let boldItalic = NSFontManager.shared.font(
                        withFamily: NSFont.systemFont(ofSize: 13).familyName ?? "",
                        traits: [.boldFontMask, .italicFontMask],
                        weight: 0,
                        size: 13
                    ) {
                        newFont = boldItalic
                    }
                } else if traits.contains(.boldFontMask) {
                    newFont = NSFont.boldSystemFont(ofSize: 13)
                } else if traits.contains(.italicFontMask) {
                    if let italic = NSFontManager.shared.font(
                        withFamily: NSFont.systemFont(ofSize: 13).familyName ?? "",
                        traits: .italicFontMask,
                        weight: 5,
                        size: 13
                    ) {
                        newFont = italic
                    }
                }
                mutableAttrString.addAttribute(.font, value: newFont, range: range)
            }
        }

        // Convert to SwiftUI AttributedString
        do {
            return try AttributedString(mutableAttrString, including: \.appKit)
        } catch {
            return AttributedString(truncated.string)
        }
    }


    private var imagePreview: some View {
        HStack(alignment: .center, spacing: 8) {
            // Thumbnail (lazy loaded via decorator)
            if let thumbnail = decorator.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                // Show loading placeholder while thumbnail is being loaded
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Image")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                // Use cached totalSizeBytes (no data load needed)
                if decorator.totalSizeBytes > 0 {
                    Text(formatFileSize(Int(decorator.totalSizeBytes)))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filePreview: some View {
        HStack(alignment: .center, spacing: 8) {
            // File icon
            Image(systemName: fileSystemImage)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                if let urls = decorator.fileURLs {
                    if urls.count == 1 {
                        Text(urls[0].lastPathComponent)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(urls[0].deletingLastPathComponent().path)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(urls.count) files")
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)

                        Text(urls.map { $0.lastPathComponent }.prefix(3).joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var fileSystemImage: String {
        guard let urls = decorator.fileURLs, let firstURL = urls.first else {
            return "doc"
        }

        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: firstURL.path, isDirectory: &isDirectory)

        if isDirectory.boolValue {
            return "folder"
        }

        // Check extension
        let ext = firstURL.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return "doc.text"
        case "png", "jpg", "jpeg", "gif", "heic":
            return "photo"
        case "mp3", "wav", "m4a":
            return "music.note"
        case "mp4", "mov", "avi":
            return "film"
        case "zip", "tar", "gz":
            return "archivebox"
        case "swift", "js", "py", "html", "css":
            return "doc.text.fill"
        default:
            return "doc"
        }
    }

    private func isURL(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://")
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    VStack {
        HistoryItemRow(
            decorator: {
                let manager = ClipboardHistoryManager(persistenceController: PersistenceController(inMemory: true))
                let context = manager.viewContext
                let item = ClipboardItem.create(in: context, type: .text, textContent: "Hello, World! This is a sample clipboard item with some longer text.", contentHash: "abc123")
                return ClipboardItemDecorator(item: item)
            }(),
            index: 1,
            isSelected: true
        )
    }
    .frame(width: 360)
    .padding()
}
