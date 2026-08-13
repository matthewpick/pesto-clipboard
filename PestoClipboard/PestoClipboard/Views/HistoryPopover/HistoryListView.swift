import SwiftUI

struct HistoryListView: View {
    @ObservedObject var viewModel: HistoryViewModel
    let isSearchFocused: Bool
    let onDismiss: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(Array(viewModel.filteredDecorators.enumerated()), id: \.element.id) { index, decorator in
                    HistoryItemRow(
                        decorator: decorator,
                        index: index + 1,
                        isSelected: index == viewModel.selectedIndex && !isSearchFocused,
                        onToggleStar: { viewModel.historyManager.togglePin(decorator.item) }
                    )
                    .id(decorator.id)
                    .tag(decorator.id)
                    .onTapGesture {
                        viewModel.handleItemTap(at: index, onDismiss: onDismiss)
                    }
                    .onAppear {
                        decorator.isVisible = true
                        decorator.ensureThumbnailImage()
                    }
                    .onDisappear {
                        decorator.isVisible = false
                        // Delay cleanup to avoid thrashing during fast scrolling
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if !decorator.isVisible {
                                decorator.cleanupImages()
                            }
                        }
                    }
                    .contextMenu {
                        ItemContextMenu(
                            item: decorator.item,
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
            .onChange(of: viewModel.filteredDecorators) { _, newDecorators in
                if !viewModel.suppressScrollToTop, let first = newDecorators.first {
                    proxy.scrollTo(first.id, anchor: .top)
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
        if let first = viewModel.filteredDecorators.first {
            proxy.scrollTo(first.id, anchor: .top)
        }
    }

    private func scrollToSelected(index: Int, proxy: ScrollViewProxy) {
        if index >= 0 && index < viewModel.filteredDecorators.count {
            withAnimation {
                proxy.scrollTo(viewModel.filteredDecorators[index].id, anchor: .center)
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

    /// Writes through to the history manager so picking a preset applies it immediately.
    private var expiration: Binding<ExpirationOption> {
        Binding(
            get: { item.expirationOption },
            set: { viewModel.historyManager.setExpiration($0, for: item) }
        )
    }

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

        Picker(selection: expiration) {
            ForEach(ExpirationOption.allCases) { option in
                Text(option.localizedName).tag(option)
            }
        } label: {
            Label("Expire After", systemImage: "clock")
        }
        .pickerStyle(.menu)

        Divider()

        Button(role: .destructive) {
            viewModel.historyManager.deleteItem(item)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}
