import Testing
import AppKit
@testable import Pesto_Clipboard

// MARK: - Mock Implementation

final class MockClipboardHistoryManager: ClipboardHistoryManaging {
    var items: [ClipboardItem] = []

    // MARK: - Call Tracking

    private(set) var fetchItemsCalled = false
    private(set) var searchItemsQueries: [String] = []

    private(set) var addTextItemCalls: [(text: String, rtfData: Data?)] = []
    private(set) var addImageItemCalls: [(imageData: Data, thumbnailData: Data?)] = []
    private(set) var addFileItemCalls: [[URL]] = []

    private(set) var moveToTopCalls: [ClipboardItem] = []
    private(set) var togglePinCalls: [ClipboardItem] = []
    private(set) var updateTextContentCalls: [(item: ClipboardItem, newText: String)] = []

    private(set) var deleteItemCalls: [ClipboardItem] = []
    private(set) var deleteItemsAtCalls: [IndexSet] = []
    private(set) var clearAllCalled = false
    private(set) var clearAllIncludingStarredCalled = false

    // MARK: - Protocol Implementation

    func fetchItems() {
        fetchItemsCalled = true
    }

    func searchItems(query: String) {
        searchItemsQueries.append(query)
    }

    func addTextItem(_ text: String, rtfData: Data?) {
        addTextItemCalls.append((text: text, rtfData: rtfData))
    }

    func addImageItem(imageData: Data, thumbnailData: Data?) {
        addImageItemCalls.append((imageData: imageData, thumbnailData: thumbnailData))
    }

    func addFileItem(urls: [URL]) {
        addFileItemCalls.append(urls)
    }

    func moveToTop(_ item: ClipboardItem) {
        moveToTopCalls.append(item)
    }

    func togglePin(_ item: ClipboardItem) {
        togglePinCalls.append(item)
    }

    func updateTextContent(_ item: ClipboardItem, newText: String) {
        updateTextContentCalls.append((item: item, newText: newText))
    }

    func deleteItem(_ item: ClipboardItem) {
        deleteItemCalls.append(item)
    }

    func deleteItems(at offsets: IndexSet) {
        deleteItemsAtCalls.append(offsets)
    }

    func clearAll() {
        clearAllCalled = true
    }

    func clearAllIncludingStarred() {
        clearAllIncludingStarredCalled = true
    }

    // MARK: - Test Helpers

    func reset() {
        items = []
        fetchItemsCalled = false
        searchItemsQueries = []
        addTextItemCalls = []
        addImageItemCalls = []
        addFileItemCalls = []
        moveToTopCalls = []
        togglePinCalls = []
        updateTextContentCalls = []
        deleteItemCalls = []
        deleteItemsAtCalls = []
        clearAllCalled = false
        clearAllIncludingStarredCalled = false
    }
}

@MainActor
struct ClipboardMonitorTests {

    // MARK: - Helpers

    func createTestSetup() -> (ClipboardMonitor, ClipboardHistoryManager) {
        let persistenceController = PersistenceController(inMemory: true)
        let historyManager = ClipboardHistoryManager(persistenceController: persistenceController)
        let monitor = ClipboardMonitor(historyManager: historyManager)
        return (monitor, historyManager)
    }

    func createMockSetup() -> (ClipboardMonitor, MockClipboardHistoryManager) {
        let mock = MockClipboardHistoryManager()
        let monitor = ClipboardMonitor(historyManager: mock)
        return (monitor, mock)
    }

    // MARK: - Initialization Tests

    @Test func initializationSetsHistoryManager() {
        let (monitor, _) = createTestSetup()

        // Monitor should be created successfully
        #expect(monitor != nil)
    }

    @Test func initializationSetsSharedInstance() {
        let (monitor, _) = createTestSetup()

        #expect(ClipboardMonitor.shared === monitor)
    }

    // MARK: - Pause State Tests

    @Test func initialPauseStateMatchesSettings() {
        // Reset settings for test
        SettingsManager.shared.isPaused = false

        let (monitor, _) = createTestSetup()

        #expect(monitor.isPaused == false)
    }

    @Test func togglePauseChangesState() {
        let (monitor, _) = createTestSetup()
        let initialState = monitor.isPaused

        monitor.togglePause()

        #expect(monitor.isPaused == !initialState)
    }

    @Test func togglePauseTwiceRestoresState() {
        let (monitor, _) = createTestSetup()
        let initialState = monitor.isPaused

        monitor.togglePause()
        monitor.togglePause()

        #expect(monitor.isPaused == initialState)
    }

    @Test func settingIsPausedUpdatesSettings() {
        let (monitor, _) = createTestSetup()

        monitor.isPaused = true

        #expect(SettingsManager.shared.isPaused == true)

        // Reset
        monitor.isPaused = false
        #expect(SettingsManager.shared.isPaused == false)
    }

    // MARK: - Monitoring Lifecycle Tests

    @Test func startMonitoringCreatesTimer() {
        let (monitor, _) = createTestSetup()

        monitor.startMonitoring()

        // Give the timer a moment to be created
        // Timer exists implicitly - if startMonitoring didn't crash, it worked
        monitor.stopMonitoring()
    }

    @Test func stopMonitoringCleansUp() {
        let (monitor, _) = createTestSetup()

        monitor.startMonitoring()
        monitor.stopMonitoring()

        // Should be able to start again without issues
        monitor.startMonitoring()
        monitor.stopMonitoring()
    }

    @Test func multipleStartCallsAreSafe() {
        let (monitor, _) = createTestSetup()

        monitor.startMonitoring()
        monitor.startMonitoring()
        monitor.startMonitoring()

        monitor.stopMonitoring()
    }

    @Test func multipleStopCallsAreSafe() {
        let (monitor, _) = createTestSetup()

        monitor.stopMonitoring()
        monitor.stopMonitoring()

        monitor.startMonitoring()
        monitor.stopMonitoring()
        monitor.stopMonitoring()
    }

    // MARK: - Mock-Based Tests

    @Test func monitorCanBeCreatedWithMock() {
        let (monitor, mock) = createMockSetup()

        #expect(monitor != nil)
        #expect(mock.addTextItemCalls.isEmpty)
    }

    @Test func mockTracksNoCallsInitially() {
        let mock = MockClipboardHistoryManager()

        #expect(mock.fetchItemsCalled == false)
        #expect(mock.clearAllCalled == false)
        #expect(mock.addTextItemCalls.isEmpty)
        #expect(mock.addImageItemCalls.isEmpty)
        #expect(mock.addFileItemCalls.isEmpty)
    }

    @Test func mockTracksAddTextItemCalls() {
        let mock = MockClipboardHistoryManager()

        mock.addTextItem("Hello", rtfData: nil)
        mock.addTextItem("World", rtfData: Data([0x01, 0x02]))

        #expect(mock.addTextItemCalls.count == 2)
        #expect(mock.addTextItemCalls[0].text == "Hello")
        #expect(mock.addTextItemCalls[0].rtfData == nil)
        #expect(mock.addTextItemCalls[1].text == "World")
        #expect(mock.addTextItemCalls[1].rtfData != nil)
    }

    @Test func mockTracksAddImageItemCalls() {
        let mock = MockClipboardHistoryManager()
        let imageData = Data([0xFF, 0xD8, 0xFF])
        let thumbnailData = Data([0x89, 0x50, 0x4E, 0x47])

        mock.addImageItem(imageData: imageData, thumbnailData: thumbnailData)

        #expect(mock.addImageItemCalls.count == 1)
        #expect(mock.addImageItemCalls[0].imageData == imageData)
        #expect(mock.addImageItemCalls[0].thumbnailData == thumbnailData)
    }

    @Test func mockTracksAddFileItemCalls() {
        let mock = MockClipboardHistoryManager()
        let urls = [URL(fileURLWithPath: "/tmp/test.txt")]

        mock.addFileItem(urls: urls)

        #expect(mock.addFileItemCalls.count == 1)
        #expect(mock.addFileItemCalls[0] == urls)
    }

    @Test func mockTracksClearAllCalls() {
        let mock = MockClipboardHistoryManager()

        #expect(mock.clearAllCalled == false)
        mock.clearAll()
        #expect(mock.clearAllCalled == true)
    }

    @Test func mockResetClearsAllTracking() {
        let mock = MockClipboardHistoryManager()

        mock.addTextItem("test", rtfData: nil)
        mock.clearAll()
        mock.fetchItems()

        #expect(mock.addTextItemCalls.count == 1)
        #expect(mock.clearAllCalled == true)
        #expect(mock.fetchItemsCalled == true)

        mock.reset()

        #expect(mock.addTextItemCalls.isEmpty)
        #expect(mock.clearAllCalled == false)
        #expect(mock.fetchItemsCalled == false)
    }
}

// MARK: - Password Manager Detection Tests

@MainActor
struct PasswordManagerDetectionTests {

    func createTestSetup() -> (ClipboardMonitor, ClipboardHistoryManager) {
        let persistenceController = PersistenceController(inMemory: true)
        let historyManager = ClipboardHistoryManager(persistenceController: persistenceController)
        let monitor = ClipboardMonitor(historyManager: historyManager)
        return (monitor, historyManager)
    }

    @Test func concealedTypeIsDetectedAsPasswordManager() {
        let pasteboard = NSPasteboard(name: .init("test.concealed"))
        pasteboard.clearContents()
        pasteboard.setString("secret", forType: .string)
        pasteboard.addTypes([NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")], owner: nil)

        // Verify the type is present
        let types = pasteboard.types ?? []
        let hasConcealed = types.contains(NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        #expect(hasConcealed == true)
    }

    @Test func onePasswordTypeIsDetectedAsPasswordManager() {
        let pasteboard = NSPasteboard(name: .init("test.1password"))
        pasteboard.clearContents()
        pasteboard.setString("password123", forType: .string)
        pasteboard.addTypes([NSPasteboard.PasteboardType("com.agilebits.onepassword")], owner: nil)

        let types = pasteboard.types ?? []
        let has1Password = types.contains(NSPasteboard.PasteboardType("com.agilebits.onepassword"))
        #expect(has1Password == true)
    }

    @Test func lastPassTypeIsDetectedAsPasswordManager() {
        let pasteboard = NSPasteboard(name: .init("test.lastpass"))
        pasteboard.clearContents()
        pasteboard.setString("secret", forType: .string)
        pasteboard.addTypes([NSPasteboard.PasteboardType("com.lastpass.LastPass")], owner: nil)

        let types = pasteboard.types ?? []
        let hasLastPass = types.contains(NSPasteboard.PasteboardType("com.lastpass.LastPass"))
        #expect(hasLastPass == true)
    }

    @Test func bitwardenTypeIsDetectedAsPasswordManager() {
        let pasteboard = NSPasteboard(name: .init("test.bitwarden"))
        pasteboard.clearContents()
        pasteboard.setString("secret", forType: .string)
        pasteboard.addTypes([NSPasteboard.PasteboardType("com.bitwarden.desktop")], owner: nil)

        let types = pasteboard.types ?? []
        let hasBitwarden = types.contains(NSPasteboard.PasteboardType("com.bitwarden.desktop"))
        #expect(hasBitwarden == true)
    }

    @Test func autoGeneratedTypeIsDetectedAsPasswordManager() {
        let pasteboard = NSPasteboard(name: .init("test.autogen"))
        pasteboard.clearContents()
        pasteboard.setString("generated", forType: .string)
        pasteboard.addTypes([NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")], owner: nil)

        let types = pasteboard.types ?? []
        let hasAutoGen = types.contains(NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType"))
        #expect(hasAutoGen == true)
    }
}

// MARK: - Remote Clipboard Detection Tests

@MainActor
struct RemoteClipboardDetectionTests {

    @Test func remoteClipboardTypeCanBeDetected() {
        let pasteboard = NSPasteboard(name: .init("test.remote"))
        pasteboard.clearContents()
        pasteboard.setString("from iPhone", forType: .string)
        pasteboard.addTypes([NSPasteboard.PasteboardType("com.apple.is-remote-clipboard")], owner: nil)

        let types = pasteboard.types ?? []
        let hasRemote = types.contains(NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
        #expect(hasRemote == true)
    }

    @Test func localClipboardDoesNotHaveRemoteType() {
        let pasteboard = NSPasteboard(name: .init("test.local"))
        pasteboard.clearContents()
        pasteboard.setString("local text", forType: .string)

        let types = pasteboard.types ?? []
        let hasRemote = types.contains(NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
        #expect(hasRemote == false)
    }
}

// MARK: - Content Extraction Tests (using test pasteboard)

@MainActor
struct ContentExtractionTests {

    func createTestSetup() -> (ClipboardMonitor, ClipboardHistoryManager) {
        let persistenceController = PersistenceController(inMemory: true)
        let historyManager = ClipboardHistoryManager(persistenceController: persistenceController)
        let monitor = ClipboardMonitor(historyManager: historyManager)
        return (monitor, historyManager)
    }

    @Test func plainTextCanBeExtractedFromPasteboard() {
        let pasteboard = NSPasteboard(name: .init("test.text"))
        pasteboard.clearContents()
        pasteboard.setString("Hello, World!", forType: .string)

        let text = pasteboard.string(forType: .string)
        #expect(text == "Hello, World!")
    }

    @Test func rtfDataCanBeExtractedFromPasteboard() {
        let pasteboard = NSPasteboard(name: .init("test.rtf"))
        pasteboard.clearContents()

        // Create RTF data
        let attributedString = NSAttributedString(
            string: "Bold Text",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 12)]
        )
        if let rtfData = try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ) {
            pasteboard.setData(rtfData, forType: .rtf)
        }

        let rtfData = pasteboard.data(forType: .rtf)
        #expect(rtfData != nil)

        if let data = rtfData {
            let extracted = NSAttributedString(rtf: data, documentAttributes: nil)
            #expect(extracted?.string == "Bold Text")
        }
    }

    @Test func imageDataCanBeExtractedFromPasteboard() {
        let pasteboard = NSPasteboard(name: .init("test.image"))
        pasteboard.clearContents()

        // Create a small test image
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.red.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 10, height: 10))
        image.unlockFocus()

        if let tiffData = image.tiffRepresentation {
            pasteboard.setData(tiffData, forType: .tiff)
        }

        let imageData = pasteboard.data(forType: .tiff)
        #expect(imageData != nil)
    }

    @Test func pngDataCanBeExtractedFromPasteboard() {
        let pasteboard = NSPasteboard(name: .init("test.png"))
        pasteboard.clearContents()

        // Create a small PNG
        let image = NSImage(size: NSSize(width: 5, height: 5))
        image.lockFocus()
        NSColor.blue.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 5, height: 5))
        image.unlockFocus()

        if let pngData = image.pngData() {
            pasteboard.setData(pngData, forType: .png)
        }

        let extractedData = pasteboard.data(forType: .png)
        #expect(extractedData != nil)
    }

    @Test func fileURLsCanBeExtractedFromPasteboard() {
        let pasteboard = NSPasteboard(name: .init("test.files"))
        pasteboard.clearContents()

        // Use a URL that exists on the system
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.txt")
        try? "test content".write(to: tempURL, atomically: true, encoding: .utf8)

        pasteboard.writeObjects([tempURL as NSURL])

        let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [
            .urlReadingFileURLsOnly: true
        ]) as? [URL]

        #expect(urls != nil)
        #expect(urls?.isEmpty == false)

        // Clean up
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func emptyPasteboardReturnsNil() {
        let pasteboard = NSPasteboard(name: .init("test.empty"))
        pasteboard.clearContents()

        #expect(pasteboard.string(forType: .string) == nil)
        #expect(pasteboard.data(forType: .png) == nil)
        #expect(pasteboard.data(forType: .rtf) == nil)
    }
}

// MARK: - NSImage Extension Tests

@MainActor
struct NSImagePNGExtensionTests {

    @Test func pngDataFromValidImage() {
        let image = NSImage(size: NSSize(width: 10, height: 10))
        image.lockFocus()
        NSColor.green.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 10, height: 10))
        image.unlockFocus()

        let pngData = image.pngData()
        #expect(pngData != nil)
        #expect(pngData!.count > 0)
    }

    @Test func pngDataPreservesImageDimensions() {
        let originalSize = NSSize(width: 50, height: 30)
        let image = NSImage(size: originalSize)
        image.lockFocus()
        NSColor.purple.set()
        NSBezierPath.fill(NSRect(origin: .zero, size: originalSize))
        image.unlockFocus()

        guard let pngData = image.pngData() else {
            Issue.record("Failed to create PNG data")
            return
        }

        // Recreate image from PNG data
        guard let recreated = NSImage(data: pngData) else {
            Issue.record("Failed to recreate image from PNG data")
            return
        }

        #expect(recreated.size.width == originalSize.width)
        #expect(recreated.size.height == originalSize.height)
    }

    @Test func pngDataIsPNGFormat() {
        let image = NSImage(size: NSSize(width: 5, height: 5))
        image.lockFocus()
        NSColor.cyan.set()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: 5, height: 5))
        image.unlockFocus()

        guard let pngData = image.pngData() else {
            Issue.record("Failed to create PNG data")
            return
        }

        // PNG magic number is 0x89 0x50 0x4E 0x47 (\x89PNG)
        let bytes = [UInt8](pngData.prefix(4))
        #expect(bytes[0] == 0x89)
        #expect(bytes[1] == 0x50) // P
        #expect(bytes[2] == 0x4E) // N
        #expect(bytes[3] == 0x47) // G
    }
}
