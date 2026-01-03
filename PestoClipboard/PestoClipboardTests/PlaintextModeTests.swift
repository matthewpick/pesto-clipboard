import Testing
import AppKit
import CoreData
@testable import Pesto_Clipboard

@MainActor
struct PlaintextModeTests {
    let persistenceController: PersistenceController
    let context: NSManagedObjectContext

    init() {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    // MARK: - Helper to create sample RTF data

    func createSampleRTFData(text: String, bold: Bool = true) -> Data? {
        let attributes: [NSAttributedString.Key: Any] = bold
            ? [.font: NSFont.boldSystemFont(ofSize: 14)]
            : [:]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        return try? attributedString.data(
            from: NSRange(location: 0, length: attributedString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    // MARK: - RTF Data Storage Tests

    @Test func itemStoresRTFData() {
        let rtfData = createSampleRTFData(text: "Bold text")

        let item = ClipboardItem.create(
            in: context,
            type: .rtf,
            textContent: "Bold text",
            rtfData: rtfData,
            contentHash: "hash1"
        )

        #expect(item.rtfData != nil)
        #expect(item.rtfData == rtfData)
        #expect(item.textContent == "Bold text")
        #expect(item.itemType == .rtf)
    }

    @Test func plainTextItemHasNoRTFData() {
        let item = ClipboardItem.create(
            in: context,
            type: .text,
            textContent: "Plain text",
            contentHash: "hash2"
        )

        #expect(item.rtfData == nil)
        #expect(item.textContent == "Plain text")
        #expect(item.itemType == .text)
    }

    // MARK: - Plaintext Mode Paste Tests

    @Test func plaintextModePastesOnlyPlainText() {
        let rtfData = createSampleRTFData(text: "Formatted text")!
        let item = ClipboardItem.create(
            in: context,
            type: .rtf,
            textContent: "Formatted text",
            rtfData: rtfData,
            contentHash: "hash3"
        )

        let pasteboard = NSPasteboard(name: .init("test-plaintext-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Paste with plaintext mode ON
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard, asPlainText: true)

        // Should have plain text
        #expect(pasteboard.string(forType: .string) == "Formatted text")

        // Should NOT have RTF data
        #expect(pasteboard.data(forType: .rtf) == nil)

        // Verify using helper
        #expect(PasteHelper.pasteboardHasOnlyPlainText(pasteboard) == true)
        #expect(PasteHelper.pasteboardHasRTF(pasteboard) == false)
    }

    @Test func normalModePastesRTFAndPlainText() {
        let rtfData = createSampleRTFData(text: "Formatted text")!
        let item = ClipboardItem.create(
            in: context,
            type: .rtf,
            textContent: "Formatted text",
            rtfData: rtfData,
            contentHash: "hash4"
        )

        let pasteboard = NSPasteboard(name: .init("test-normal-\(UUID().uuidString)"))
        pasteboard.clearContents()

        // Paste with plaintext mode OFF
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard, asPlainText: false)

        // Should have plain text as fallback
        #expect(pasteboard.string(forType: .string) == "Formatted text")

        // Should also have RTF data
        #expect(pasteboard.data(forType: .rtf) != nil)

        // Verify using helper
        #expect(PasteHelper.pasteboardHasRTF(pasteboard) == true)
    }

    @Test func plainTextItemBehaviorSameInBothModes() {
        // Create item without RTF data
        let item = ClipboardItem.create(
            in: context,
            type: .text,
            textContent: "Just plain text",
            contentHash: "hash5"
        )

        let pasteboard1 = NSPasteboard(name: .init("test-plain1-\(UUID().uuidString)"))
        let pasteboard2 = NSPasteboard(name: .init("test-plain2-\(UUID().uuidString)"))

        // Paste in both modes
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard1, asPlainText: true)
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard2, asPlainText: false)

        // Both should have plain text
        #expect(pasteboard1.string(forType: .string) == "Just plain text")
        #expect(pasteboard2.string(forType: .string) == "Just plain text")

        // Neither should have RTF (since source had no RTF)
        #expect(pasteboard1.data(forType: .rtf) == nil)
        #expect(pasteboard2.data(forType: .rtf) == nil)
    }

    // MARK: - RTF Formatting Preservation Tests

    @Test func rtfFormattingIsPreservedInNormalMode() {
        let originalText = "Bold and styled"
        let rtfData = createSampleRTFData(text: originalText, bold: true)!

        let item = ClipboardItem.create(
            in: context,
            type: .rtf,
            textContent: originalText,
            rtfData: rtfData,
            contentHash: "hash6"
        )

        let pasteboard = NSPasteboard(name: .init("test-format-\(UUID().uuidString)"))

        // Paste normally (not plaintext)
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard, asPlainText: false)

        // Retrieve RTF data and verify it can be parsed
        guard let retrievedRTF = pasteboard.data(forType: .rtf) else {
            Issue.record("RTF data should be present")
            return
        }

        // Parse the RTF to verify it's valid
        let attributedString = NSAttributedString(rtf: retrievedRTF, documentAttributes: nil)
        #expect(attributedString != nil)
        #expect(attributedString?.string == originalText)
    }

    @Test func rtfFormattingIsStrippedInPlaintextMode() {
        let originalText = "Bold and styled"
        let rtfData = createSampleRTFData(text: originalText, bold: true)!

        let item = ClipboardItem.create(
            in: context,
            type: .rtf,
            textContent: originalText,
            rtfData: rtfData,
            contentHash: "hash7"
        )

        let pasteboard = NSPasteboard(name: .init("test-strip-\(UUID().uuidString)"))

        // Paste with plaintext mode
        PasteHelper.writeToClipboard(item: item, pasteboard: pasteboard, asPlainText: true)

        // Should have plain text
        #expect(pasteboard.string(forType: .string) == originalText)

        // Should NOT have RTF
        #expect(pasteboard.data(forType: .rtf) == nil)
    }

    // MARK: - ClipboardHistoryManager RTF Storage Tests

    @Test func historyManagerStoresRTFData() {
        // Use isolated persistence controller to avoid test pollution
        let isolatedController = PersistenceController(inMemory: true)
        let manager = ClipboardHistoryManager(
            persistenceController: isolatedController,
            maxItems: 100
        )

        let rtfData = createSampleRTFData(text: "Rich text")

        manager.addTextItem("Rich text", rtfData: rtfData)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.rtfData != nil)
        #expect(manager.items.first?.itemType == .rtf)
    }

    @Test func historyManagerPlainTextHasNoRTF() {
        // Use isolated persistence controller to avoid test pollution
        let isolatedController = PersistenceController(inMemory: true)
        let manager = ClipboardHistoryManager(
            persistenceController: isolatedController,
            maxItems: 100
        )

        manager.addTextItem("Plain text", rtfData: nil)

        #expect(manager.items.count == 1)
        #expect(manager.items.first?.rtfData == nil)
        #expect(manager.items.first?.itemType == .text)
    }
}
