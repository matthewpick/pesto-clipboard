import AppKit
import Combine
import os.log
import UniformTypeIdentifiers

class ClipboardMonitor: ObservableObject {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PestoClipboard", category: "ClipboardMonitor")
    static var shared: ClipboardMonitor?

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

        // Ignore clipboard content from other devices (Universal Clipboard)
        if settings.ignoreRemoteClipboard && isFromRemoteDevice(pasteboard: pasteboard) {
            Self.logger.debug("Ignored remote clipboard content (Universal Clipboard)")
            return
        }

        // Always ignore password manager content (security)
        if isFromPasswordManager(pasteboard: pasteboard) {
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
            // Generate thumbnail using QuickLook (works for images, PDFs, videos, documents, etc.)
            let thumbnailData = ThumbnailGenerator.generateThumbnailFromFirstFile(urls: fileURLs, maxSize: Constants.thumbnailMaxSize)
            if thumbnailData != nil {
                Self.logger.info("Captured \(fileURLs.count) file(s) with preview thumbnail")
            } else {
                Self.logger.info("Captured \(fileURLs.count) file(s)")
            }
            historyManager.addFileItem(urls: fileURLs, thumbnailData: thumbnailData)
            return
        }

        // Check for images
        if settings.captureImages, let imageData = extractImageData(from: pasteboard) {
            let thumbnailData = ThumbnailGenerator.generateThumbnail(from: imageData, maxSize: Constants.thumbnailMaxSize)
            if thumbnailData == nil {
                Self.logger.warning("Failed to generate thumbnail for image (\(imageData.count) bytes)")
            }
            Self.logger.info("Captured image (\(imageData.count) bytes)")
            historyManager.addImageItem(imageData: imageData, thumbnailData: thumbnailData)
            return
        }

        // Check for text (including RTF)
        if settings.captureText {
            let (text, rtfData) = extractTextAndRTF(from: pasteboard)
            if let text = text, !text.isEmpty {
                Self.logger.info("Captured text (\(text.count) chars, RTF: \(rtfData != nil))")
                historyManager.addTextItem(text, rtfData: rtfData)
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

    // MARK: - Content Extraction

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
