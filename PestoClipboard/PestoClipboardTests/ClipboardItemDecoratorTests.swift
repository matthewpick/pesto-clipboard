import Testing
import AppKit
import CoreData
@testable import Pesto_Clipboard

/// HistoryViewModel caches one decorator per item and reuses it for as long as that
/// item exists, so a decorator must never snapshot metadata the app can change later.
/// These cover the mutations the UI can perform on an item that is already on screen.
@MainActor
struct ClipboardItemDecoratorTests {

    // MARK: - Helpers

    private func createManager() -> ClipboardHistoryManager {
        ClipboardHistoryManager(
            persistenceController: PersistenceController(inMemory: true),
            maxItems: 500
        )
    }

    private func createViewModel(
        _ manager: ClipboardHistoryManager
    ) -> HistoryViewModel {
        HistoryViewModel(
            historyManager: manager,
            clipboardMonitor: ClipboardMonitor(historyManager: manager)
        )
    }

    private func rtfData(for text: String) -> Data? {
        let attributed = NSAttributedString(
            string: text,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 14)]
        )
        return try? attributed.data(
            from: NSRange(location: 0, length: attributed.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    // MARK: - Decorator Caching

    @Test func decoratorIsReusedForTheSameItem() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("hello")

        let first = viewModel.filteredDecorators[0]
        let second = viewModel.filteredDecorators[0]

        #expect(first === second, "decorators are cached so lazily loaded thumbnails survive re-renders")
    }

    @Test func decoratorIsDiscardedWhenItsItemGoesAway() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("hello")

        let decorator = viewModel.filteredDecorators[0]
        manager.deleteItem(decorator.item)

        #expect(viewModel.filteredDecorators.isEmpty)
    }

    // MARK: - Starring

    // Regression: `isPinned` was snapshotted at init, so a cached decorator kept
    // reporting the old value and the row's star glyph never changed.
    @Test func starringAnItemIsVisibleThroughTheCachedDecorator() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("hello")

        let decorator = viewModel.filteredDecorators[0]
        #expect(decorator.isPinned == false)

        manager.togglePin(decorator.item)

        #expect(manager.items[0].isPinned == true, "core data was updated")
        #expect(viewModel.filteredDecorators[0].isPinned == true, "the row must see it too")
        #expect(decorator.isPinned == true, "including through the instance the row already holds")
    }

    @Test func unstarringAnItemIsVisibleThroughTheCachedDecorator() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("hello")

        let decorator = viewModel.filteredDecorators[0]
        manager.togglePin(decorator.item)
        #expect(decorator.isPinned == true)

        manager.togglePin(decorator.item)

        #expect(decorator.isPinned == false)
    }

    // MARK: - Editing

    // Regression: `textContent`/`previewText` were snapshotted too, so an edit
    // never appeared in the list.
    @Test func editingAnItemIsVisibleThroughTheCachedDecorator() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("original")

        let decorator = viewModel.filteredDecorators[0]
        #expect(decorator.textContent == "original")

        manager.updateTextContent(decorator.item, newText: "edited")

        #expect(decorator.textContent == "edited")
        #expect(decorator.previewText == "edited")
        #expect(decorator.displayText == "edited")
    }

    @Test func editingARichTextItemClearsItsRenderedFormatting() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("original", rtfData: rtfData(for: "original"))

        let decorator = viewModel.filteredDecorators[0]
        #expect(decorator.attributedString?.string == "original")

        manager.updateTextContent(decorator.item, newText: "edited")

        #expect(decorator.textContent == "edited")
        // The row renders `attributedString` in preference to `textContent`, so a
        // leftover RTF payload here would keep showing the pre-edit text.
        #expect(decorator.attributedString == nil)
    }

    // MARK: - Reordering

    @Test func movingAnItemToTopIsVisibleThroughTheCachedDecorator() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("hello")

        let decorator = viewModel.filteredDecorators[0]
        let originalDate = decorator.createdAt

        manager.moveToTop(decorator.item)

        #expect(decorator.createdAt > originalDate)
    }

    // MARK: - Immutable Metadata

    @Test func immutableMetadataIsStillAvailable() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        manager.addTextItem("hello")

        let decorator = viewModel.filteredDecorators[0]

        #expect(decorator.id == decorator.item.id)
        #expect(decorator.itemType == .text)
        #expect(decorator.contentType == ClipboardItemType.text.rawValue)
        #expect(decorator.fileURLs == nil)
        #expect(decorator.totalSizeBytes == 0)
    }

    @Test func fileItemDecoratorExposesItsURLs() {
        let manager = createManager()
        let viewModel = createViewModel(manager)
        let url = URL(fileURLWithPath: "/tmp/pesto-decorator-test.txt")
        manager.addFileItem(urls: [url])

        let decorator = viewModel.filteredDecorators[0]

        #expect(decorator.itemType == .file)
        #expect(decorator.fileURLs == [url])
        #expect(decorator.displayText == "pesto-decorator-test.txt")
    }
}
