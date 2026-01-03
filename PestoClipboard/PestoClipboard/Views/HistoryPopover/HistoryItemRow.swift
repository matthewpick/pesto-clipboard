import SwiftUI

struct HistoryItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isSelected: Bool
    var onToggleStar: () -> Void = {}

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // Star indicator (always visible, vertically centered)
            Button {
                onToggleStar()
            } label: {
                Image(systemName: item.isPinned ? "star.fill" : "star")
                    .font(.system(size: 13))
                    .foregroundStyle(item.isPinned ? .yellow : .secondary.opacity(0.4))
                    .frame(width: 20, height: 20)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content preview
            contentPreview

            Spacer(minLength: 4)

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
        .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
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
        switch item.itemType {
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
            if let text = item.textContent, isURL(text) {
                Text(text)
                    .font(.system(size: 13, design: .default))
                    .foregroundStyle(.blue)
                    .lineLimit(2)
            } else if let nsAttributedString = item.attributedString {
                // Display rich text with formatting
                Text(attributedPreview(from: nsAttributedString))
                    .lineLimit(3)
            } else {
                Text(item.previewText)
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
            // Thumbnail
            if let thumbnail = item.thumbnailImage {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .frame(width: 36, height: 36)
                    .background(Color.secondary.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Image")
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                if let imageData = item.imageData {
                    Text(formatFileSize(imageData.count))
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
                if let urls = item.fileURLs {
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
        guard let urls = item.fileURLs, let firstURL = urls.first else {
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
            item: {
                let manager = ClipboardHistoryManager(persistenceController: PersistenceController(inMemory: true))
                let context = manager.viewContext
                return ClipboardItem.create(in: context, type: .text, textContent: "Hello, World! This is a sample clipboard item with some longer text.", contentHash: "abc123")
            }(),
            index: 1,
            isSelected: true
        )
    }
    .frame(width: 360)
    .padding()
}
