import AppKit
import Combine
import os.log
import UniformTypeIdentifiers

class ClipboardMonitor: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PestoClipboard", category: "ClipboardMonitor")
    static var shared: ClipboardMonitor?

    /// Marker type used to identify clipboard content written by Pesto
    static let pestoPasteboardType = NSPasteboard.PasteboardType("com.pestoclipboard.source-marker")

    private let historyManager: ClipboardHistoryManaging
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let pollInterval: TimeInterval = Constants.clipboardPollInterval
    private var skipNextCheck: Bool = false

    @Published var isPaused: Bool = SettingsManager.shared.isPaused {
        didSet {
            // Persist to settings
            SettingsManager.shared.isPaused = isPaused

            if !isPaused {
                // When unpausing, update lastChangeCount to current
                // and skip the next check cycle to avoid capturing current clipboard
                lastChangeCount = NSPasteboard.general.changeCount
                skipNextCheck = true
            }
        }
    }

    init(historyManager: ClipboardHistoryManaging) {
        self.historyManager = historyManager
        self.lastChangeCount = NSPasteboard.general.changeCount
        ClipboardMonitor.shared = self
    }

    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        // Add to common run loop mode so it works during UI interactions
        RunLoop.current.add(timer!, forMode: .common)
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func togglePause() {
        isPaused.toggle()
    }

    private func checkForChanges() {
        // Skip if paused
        guard !isPaused else { return }

        // Skip one cycle after unpausing to avoid capturing current clipboard
        if skipNextCheck {
            skipNextCheck = false
            lastChangeCount = NSPasteboard.general.changeCount
            return
        }

        let pasteboard = NSPasteboard.general
        let currentChangeCount = pasteboard.changeCount

        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        // Extract content from pasteboard
        extractAndStoreContent(from: pasteboard)
    }

    private func extractAndStoreContent(from pasteboard: NSPasteboard) {
        let settings = SettingsManager.shared

        // Ignore clipboard content from Pesto itself (prevents re-capturing pasted items)
        if isFromPesto(pasteboard: pasteboard) {
            Self.logger.debug("Ignored clipboard content from Pesto (self-detection)")
            return
        }

        // Ignore clipboard content from other devices (Universal Clipboard)
        if settings.ignoreRemoteClipboard && isFromRemoteDevice(pasteboard: pasteboard) {
            Self.logger.debug("Ignored remote clipboard content (Universal Clipboard)")
            return
        }

        // Ignore password manager content (security) - configurable
        if settings.ignorePasswordManagers && isFromPasswordManager(pasteboard: pasteboard) {
            Self.logger.debug("Ignored password manager content")
            return
        }

        // Check if the source app is ignored (frontmost app)
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundlePath = frontApp.bundleURL?.path,
           settings.ignoredApps.contains(bundlePath) {
            Self.logger.debug("Ignored content from app: \(frontApp.localizedName ?? bundlePath, privacy: .public)")
            return
        }

        // Check for files first (most specific)
        if settings.captureFiles, let fileURLs = extractFileURLs(from: pasteboard), !fileURLs.isEmpty {
            Self.logger.info("Captured \(fileURLs.count) file(s)")
            historyManager.addFileItem(urls: fileURLs)
            return
        }

        // Check for images - extract ALL available formats
        if settings.captureImages {
            let imageContents = extractAllImageContents(from: pasteboard)
            if !imageContents.isEmpty {
                // Find best format for thumbnail generation (prefer PNG/TIFF over PDF)
                let thumbnailSourceData = imageContents.first { $0.type == NSPasteboard.PasteboardType.png.rawValue }?.data
                    ?? imageContents.first { $0.type == NSPasteboard.PasteboardType.tiff.rawValue }?.data
                    ?? imageContents.first?.data

                let thumbnailData: Data?
                if let sourceData = thumbnailSourceData {
                    thumbnailData = ThumbnailGenerator.generateThumbnail(from: sourceData, maxSize: Constants.thumbnailMaxSize)
                    if thumbnailData == nil {
                        Self.logger.warning("Failed to generate thumbnail for image")
                    }
                } else {
                    thumbnailData = nil
                }

                let totalSize = imageContents.reduce(0) { $0 + $1.data.count }
                Self.logger.info("Captured image with \(imageContents.count) format(s), total \(totalSize) bytes")
                historyManager.addImageItem(contents: imageContents, thumbnailData: thumbnailData)
                return
            }
        }

        // Check for text (including RTF)
        if settings.captureText {
            let (text, rtfData) = extractTextAndRTF(from: pasteboard)
            if let text = text, !text.isEmpty {
                if settings.plainTextMode {
                    // Plaintext mode: store the item as plain text (no RTF) and strip
                    // formatting from the live clipboard so any paste, in any app, is plain.
                    Self.logger.info("Captured text (\(text.count) chars, plaintext mode)")
                    historyManager.addTextItem(text, rtfData: nil)
                    if pasteboardHasFormatting(pasteboard) {
                        PasteHelper.writePlainText(text, to: pasteboard)
                        lastChangeCount = pasteboard.changeCount
                    }
                } else {
                    Self.logger.info("Captured text (\(text.count) chars, RTF: \(rtfData != nil))")
                    historyManager.addTextItem(text, rtfData: rtfData)
                }
                return
            }
        }

        // Log when nothing was captured (pasteboard changed but no recognizable content)
        Self.logger.debug("Clipboard changed but no capturable content found. Types: \(pasteboard.types?.map(\.rawValue) ?? [], privacy: .public)")
    }

    // MARK: - Remote Device Detection (Universal Clipboard)

    private func isFromRemoteDevice(pasteboard: NSPasteboard) -> Bool {
        let remoteClipboardType = NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")
        return pasteboard.types?.contains(remoteClipboardType) ?? false
    }

    // MARK: - Password Manager Detection

    private func isFromPasswordManager(pasteboard: NSPasteboard) -> Bool {
        // Check for concealed/password manager pasteboard types
        // 1Password and other password managers use these types
        let passwordManagerTypes = [
            "org.nspasteboard.ConcealedType",
            "org.nspasteboard.AutoGeneratedType",
            "com.agilebits.onepassword",
            "com.lastpass.LastPass",
            "com.bitwarden.desktop"
        ]

        let availableTypes = pasteboard.types ?? []
        for type in availableTypes {
            if passwordManagerTypes.contains(type.rawValue) {
                return true
            }
        }
        return false
    }

    // MARK: - Self-Detection (Ignore Pesto's own pastes)

    private func isFromPesto(pasteboard: NSPasteboard) -> Bool {
        return pasteboard.types?.contains(Self.pestoPasteboardType) ?? false
    }

    /// Whether the pasteboard carries rich-text formatting beyond a plain string
    /// (RTF, RTFD or HTML). Used by plaintext mode to decide if the live clipboard
    /// needs to be rewritten as plain text.
    private func pasteboardHasFormatting(_ pasteboard: NSPasteboard) -> Bool {
        let richTextTypes: [NSPasteboard.PasteboardType] = [.rtf, .rtfd, .html]
        return richTextTypes.contains { pasteboard.data(forType: $0) != nil }
    }

    // MARK: - Content Extraction

    /// Represents a single pasteboard content format with its type and data
    struct PasteboardContent {
        let type: String
        let data: Data
    }

    /// Supported image pasteboard types for multi-format capture
    private static let supportedImageTypes: Set<NSPasteboard.PasteboardType> = [
        // Standard image formats
        .png,
        .tiff,
        .pdf,
        NSPasteboard.PasteboardType("public.jpeg"),
        NSPasteboard.PasteboardType("public.heic"),
        // Adobe formats
        NSPasteboard.PasteboardType("com.adobe.pdf"),
        NSPasteboard.PasteboardType("com.adobe.illustrator.ai"),
        // Affinity (Serif) native formats - preserves vectors/layers
        NSPasteboard.PasteboardType("com.seriflabs.persona.nodes"),
        NSPasteboard.PasteboardType("com.seriflabs.affinitydesigner"),
        NSPasteboard.PasteboardType("com.seriflabs.affinityphoto"),
        NSPasteboard.PasteboardType("com.seriflabs.affinitypublisher"),
    ]

    /// Extracts all available image formats from pasteboard (multi-format storage)
    private func extractAllImageContents(from pasteboard: NSPasteboard) -> [PasteboardContent] {
        var contents: [PasteboardContent] = []

        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types where Self.supportedImageTypes.contains(type) {
                if let data = item.data(forType: type) {
                    contents.append(PasteboardContent(type: type.rawValue, data: data))
                }
            }
        }

        // If no direct formats found, try NSImage fallback and convert to PNG
        if contents.isEmpty, let image = NSImage(pasteboard: pasteboard), let pngData = image.pngData() {
            contents.append(PasteboardContent(type: NSPasteboard.PasteboardType.png.rawValue, data: pngData))
        }

        return contents
    }

    private func extractFileURLs(from pasteboard: NSPasteboard) -> [URL]? {
        // Try to get file URLs
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL], !urls.isEmpty else {
            return nil
        }

        // Filter to only existing files
        let existingURLs = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
        return existingURLs.isEmpty ? nil : existingURLs
    }

    private func extractImageData(from pasteboard: NSPasteboard) -> Data? {
        // Try different image types
        let imageTypes: [NSPasteboard.PasteboardType] = [
            .png,
            .tiff,
            NSPasteboard.PasteboardType("public.jpeg")
        ]

        for type in imageTypes {
            if let data = pasteboard.data(forType: type) {
                return data
            }
        }

        // Try reading as NSImage and convert to PNG
        if let image = NSImage(pasteboard: pasteboard) {
            if let pngData = image.pngData() {
                return pngData
            }
            Self.logger.warning("Failed to convert NSImage to PNG data")
        }

        return nil
    }

    private func extractText(from pasteboard: NSPasteboard) -> String? {
        // Try plain text first
        if let text = pasteboard.string(forType: .string) {
            return text
        }

        // Try RTF and extract plain text
        if let rtfData = pasteboard.data(forType: .rtf) {
            if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                return attributedString.string
            }
        }

        return nil
    }

    /// Extracts both plain text and RTF data from pasteboard
    /// Returns tuple of (plainText, rtfData) where rtfData is nil if no RTF formatting exists
    private func extractTextAndRTF(from pasteboard: NSPasteboard) -> (String?, Data?) {
        // Check for RTF data first
        if let rtfData = pasteboard.data(forType: .rtf) {
            if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                return (attributedString.string, rtfData)
            }
        }

        // Fall back to plain text (no RTF data)
        if let text = pasteboard.string(forType: .string) {
            return (text, nil)
        }

        return (nil, nil)
    }
}

// MARK: - NSImage Extension

extension NSImage {
    func pngData() -> Data? {
        guard let tiffData = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
    }
}
