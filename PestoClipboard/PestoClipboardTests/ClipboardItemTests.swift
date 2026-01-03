import Testing
import CoreData
@testable import Pesto_Clipboard

@MainActor
struct ClipboardItemTests {
    let persistenceController: PersistenceController
    let context: NSManagedObjectContext

    init() {
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    // MARK: - Factory Method Tests

    @Test func createTextItem() {
        let item = ClipboardItem.create(
            in: context,
            type: .text,
            textContent: "Hello, World!",
            contentHash: "abc123"
        )

        #expect(item.itemType == .text)
        #expect(item.textContent == "Hello, World!")
        #expect(item.contentHash == "abc123")
        #expect(item.isPinned == false)
        #expect(item.id != UUID())
        #expect(item.createdAt <= Date())
    }

    @Test func createImageItem() {
        let imageData = Data([0x89, 0x50, 0x4E, 0x47]) // PNG header bytes
        let thumbnailData = Data([0xFF, 0xD8, 0xFF]) // JPEG header bytes

        let item = ClipboardItem.create(
            in: context,
            type: .image,
            imageData: imageData,
            thumbnailData: thumbnailData,
            contentHash: "img123"
        )

        #expect(item.itemType == .image)
        #expect(item.imageData == imageData)
        #expect(item.thumbnailData == thumbnailData)
        #expect(item.textContent == nil)
    }

    @Test func createFileItem() {
        let urls = [
            URL(fileURLWithPath: "/Users/test/file1.txt"),
            URL(fileURLWithPath: "/Users/test/file2.pdf")
        ]

        let item = ClipboardItem.create(
            in: context,
            type: .file,
            fileURLs: urls,
            contentHash: "file123"
        )

        #expect(item.itemType == .file)
        #expect(item.fileURLs?.count == 2)
        #expect(item.fileURLs?[0].lastPathComponent == "file1.txt")
        #expect(item.fileURLs?[1].lastPathComponent == "file2.pdf")
    }

    // MARK: - Computed Properties Tests

    @Test func itemTypeFromContentType() {
        let textItem = ClipboardItem.create(in: context, type: .text, contentHash: "1")
        let imageItem = ClipboardItem.create(in: context, type: .image, contentHash: "2")
        let fileItem = ClipboardItem.create(in: context, type: .file, contentHash: "3")
        let rtfItem = ClipboardItem.create(in: context, type: .rtf, contentHash: "4")

        #expect(textItem.itemType == .text)
        #expect(imageItem.itemType == .image)
        #expect(fileItem.itemType == .file)
        #expect(rtfItem.itemType == .rtf)
    }

    @Test func displayTextForTextItem() {
        let item = ClipboardItem.create(
            in: context,
            type: .text,
            textContent: "Sample text content",
            contentHash: "hash1"
        )

        #expect(item.displayText == "Sample text content")
    }

    @Test func displayTextForImageItem() {
        let item = ClipboardItem.create(
            in: context,
            type: .image,
            contentHash: "hash2"
        )

        #expect(item.displayText == "Image")
    }

    @Test func displayTextForSingleFile() {
        let urls = [URL(fileURLWithPath: "/path/to/document.pdf")]
        let item = ClipboardItem.create(
            in: context,
            type: .file,
            fileURLs: urls,
            contentHash: "hash3"
        )

        #expect(item.displayText == "document.pdf")
    }

    @Test func displayTextForMultipleFiles() {
        let urls = [
            URL(fileURLWithPath: "/path/file1.txt"),
            URL(fileURLWithPath: "/path/file2.txt"),
            URL(fileURLWithPath: "/path/file3.txt")
        ]
        let item = ClipboardItem.create(
            in: context,
            type: .file,
            fileURLs: urls,
            contentHash: "hash4"
        )

        #expect(item.displayText == "3 files")
    }

    @Test func previewTextTruncatesLongContent() {
        let longText = String(repeating: "a", count: 300)
        let item = ClipboardItem.create(
            in: context,
            type: .text,
            textContent: longText,
            contentHash: "hash5"
        )

        #expect(item.previewText.count == 203) // 200 chars + "..."
        #expect(item.previewText.hasSuffix("..."))
    }

    @Test func previewTextShortContentUnchanged() {
        let shortText = "Short text"
        let item = ClipboardItem.create(
            in: context,
            type: .text,
            textContent: shortText,
            contentHash: "hash6"
        )

        #expect(item.previewText == shortText)
    }

    // MARK: - File URLs Encoding/Decoding

    @Test func fileURLsEncodingDecoding() {
        let item = ClipboardItem.create(in: context, type: .file, contentHash: "hash7")

        let originalURLs = [
            URL(fileURLWithPath: "/Users/test/Documents/file.txt"),
            URL(fileURLWithPath: "/Users/test/Downloads/image.png")
        ]

        item.fileURLs = originalURLs

        #expect(item.fileURLs?.count == 2)
        #expect(item.fileURLs?[0] == originalURLs[0])
        #expect(item.fileURLs?[1] == originalURLs[1])
    }

    @Test func fileURLsNilWhenNoData() {
        let item = ClipboardItem.create(in: context, type: .text, contentHash: "hash8")
        #expect(item.fileURLs == nil)
    }

    // MARK: - Fetch Request Tests

    @Test func allItemsFetchRequestSortsByDate() {
        let request = ClipboardItem.allItemsFetchRequest()

        #expect(request.sortDescriptors?.count == 1)
        #expect(request.sortDescriptors?.first?.key == "createdAt")
        #expect(request.sortDescriptors?.first?.ascending == false)
    }

    @Test func searchFetchRequestWithQuery() {
        let request = ClipboardItem.searchFetchRequest(query: "test")

        #expect(request.predicate != nil)
        #expect(request.sortDescriptors?.count == 1)
    }

    @Test func searchFetchRequestWithEmptyQuery() {
        let request = ClipboardItem.searchFetchRequest(query: "")

        #expect(request.predicate == nil)
    }

    @Test func fetchRequestByHash() {
        let request = ClipboardItem.fetchRequest(byHash: "somehash")

        #expect(request.predicate != nil)
        #expect(request.fetchLimit == 1)
    }
}
