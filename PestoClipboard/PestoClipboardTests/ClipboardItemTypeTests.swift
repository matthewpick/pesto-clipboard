import Testing
@testable import Pesto_Clipboard

@MainActor
struct ClipboardItemTypeTests {

    // MARK: - Display Name Tests

    @Test func textDisplayName() {
        #expect(ClipboardItemType.text.displayName == "Text")
    }

    @Test func imageDisplayName() {
        #expect(ClipboardItemType.image.displayName == "Image")
    }

    @Test func fileDisplayName() {
        #expect(ClipboardItemType.file.displayName == "File")
    }

    @Test func rtfDisplayName() {
        #expect(ClipboardItemType.rtf.displayName == "Rich Text")
    }

    // MARK: - System Image Tests

    @Test func textSystemImage() {
        #expect(ClipboardItemType.text.systemImage == "doc.text")
    }

    @Test func imageSystemImage() {
        #expect(ClipboardItemType.image.systemImage == "photo")
    }

    @Test func fileSystemImage() {
        #expect(ClipboardItemType.file.systemImage == "doc")
    }

    @Test func rtfSystemImage() {
        #expect(ClipboardItemType.rtf.systemImage == "doc.richtext")
    }

    // MARK: - Raw Value Tests

    @Test func allCasesHaveRawValues() {
        #expect(ClipboardItemType.text.rawValue == "text")
        #expect(ClipboardItemType.image.rawValue == "image")
        #expect(ClipboardItemType.file.rawValue == "file")
        #expect(ClipboardItemType.rtf.rawValue == "rtf")
    }

    @Test func initFromRawValue() {
        #expect(ClipboardItemType(rawValue: "text") == .text)
        #expect(ClipboardItemType(rawValue: "image") == .image)
        #expect(ClipboardItemType(rawValue: "file") == .file)
        #expect(ClipboardItemType(rawValue: "rtf") == .rtf)
        #expect(ClipboardItemType(rawValue: "invalid") == nil)
    }

    @Test func caseIterableContainsAllCases() {
        let allCases = ClipboardItemType.allCases
        #expect(allCases.count == 4)
        #expect(allCases.contains(.text))
        #expect(allCases.contains(.image))
        #expect(allCases.contains(.file))
        #expect(allCases.contains(.rtf))
    }
}
