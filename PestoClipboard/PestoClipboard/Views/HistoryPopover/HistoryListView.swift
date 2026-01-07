import SwiftUI

struct HistoryListView: View {
    @ObservedObject var viewModel: HistoryViewModel
    let isSearchFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(viewModel.filteredItems.enumerated()), id: \.element.id) { index, item in
                    HistoryItemRow(
                        item: item,
                        index: index + 1,
                        isSelected: index == viewModel.selectedIndex && !isSearchFocused,
                        onToggleStar: { viewModel.historyManager.togglePin(item) }
                    )
                    .id(item.id)
                    .tag(item.id)
                    .onTapGesture {
                        viewModel.handleItemTap(at: index, onDismiss: onDismiss)
                    }
                    .contextMenu {
                        ItemContextMenu(
                            item: item,
                            index: index,
                            viewModel: viewModel,
                            onDismiss: onDismiss
                        )
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, 4)
            .onAppear {
                viewModel.selectedIndex = 0
                scrollToFirst(proxy: proxy)
            }
            .onChange(of: viewModel.filteredItems) { _, newItems in
                if !viewModel.suppressScrollToTop, let firstItem = newItems.first {
                    proxy.scrollTo(firstItem.id, anchor: .top)
                }
                viewModel.suppressScrollToTop = false
                viewModel.adjustSelectionAfterItemsChange()
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                scrollToSelected(index: newIndex, proxy: proxy)
            }
        }
    }

    private func scrollToFirst(proxy: ScrollViewProxy) {
        if let firstItem = viewModel.filteredItems.first {
            proxy.scrollTo(firstItem.id, anchor: .top)
        }
    }

    private func scrollToSelected(index: Int, proxy: ScrollViewProxy) {
        if index >= 0 && index < viewModel.filteredItems.count {
            withAnimation {
                proxy.scrollTo(viewModel.filteredItems[index].id, anchor: .center)
            }
        }
    }
}

// MARK: - Item Context Menu

struct ItemContextMenu: View {
    let item: ClipboardItem
    let index: Int
    @ObservedObject var viewModel: HistoryViewModel
    let onDismiss: () -> Void

    var body: some View {
        Button {
            viewModel.copyToClipboard(item)
        } label: {
            Label("Copy to Clipboard", systemImage: "doc.on.doc")
        }

        Divider()

        Button {
            viewModel.pasteItemAtIndex(index, asPlainText: false, onDismiss: onDismiss)
        } label: {
            Label("Paste as Original", systemImage: "doc.richtext")
        }

        Button {
            viewModel.pasteItemAtIndex(index, asPlainText: true, onDismiss: onDismiss)
        } label: {
            Label("Paste as Plaintext", systemImage: "textformat")
        }

        if item.itemType == .text || item.itemType == .rtf {
            Divider()

            Button {
                viewModel.itemToEdit = item
            } label: {
                Label("Edit", systemImage: "pencil")
            }
        }

        Divider()

        Button(role: .destructive) {
            viewModel.historyManager.deleteItem(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
