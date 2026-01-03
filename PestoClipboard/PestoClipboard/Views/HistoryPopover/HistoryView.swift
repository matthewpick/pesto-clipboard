import SwiftUI

struct HistoryView: View {
    @ObservedObject var historyManager: ClipboardHistoryManager
    @ObservedObject var clipboardMonitor: ClipboardMonitor
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = -1
    @State private var plainTextMode: Bool = false
    @State private var showStarredOnly: Bool = false
    var onDismiss: () -> Void
    var onSettings: () -> Void

    private var filteredItems: [ClipboardItem] {
        if showStarredOnly {
            return historyManager.items.filter { $0.isPinned }
        }
        return historyManager.items
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(itemCount: filteredItems.count)

            // Search bar
            SearchBar(text: $searchText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .onChange(of: searchText) { _, newValue in
                    if newValue.isEmpty {
                        historyManager.fetchItems()
                    } else {
                        historyManager.searchItems(query: newValue)
                    }
                    selectedIndex = -1
                }

            Divider()

            // History list
            if filteredItems.isEmpty {
                if !searchText.isEmpty {
                    SearchEmptyStateView(query: searchText)
                } else if showStarredOnly {
                    StarredEmptyStateView()
                } else {
                    EmptyStateView()
                }
            } else {
                ScrollViewReader { proxy in
                    List {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            HistoryItemRow(
                                item: item,
                                index: index + 1,
                                isSelected: index == selectedIndex,
                                onToggleStar: {
                                    historyManager.togglePin(item)
                                }
                            )
                            .id(item.id)
                            .tag(item.id)
                            .onTapGesture {
                                selectedIndex = index
                                if SettingsManager.shared.pasteAutomatically {
                                    pasteItem(item, asPlainText: plainTextMode)
                                } else {
                                    copyToClipboard(item)
                                    onDismiss()
                                }
                            }
                            .contextMenu {
                                Button {
                                    copyToClipboard(item)
                                } label: {
                                    Label("Copy to Clipboard", systemImage: "doc.on.doc")
                                }

                                Divider()

                                Button {
                                    selectedIndex = index
                                    pasteItem(item, asPlainText: false)
                                } label: {
                                    Label("Paste as Original", systemImage: "doc.richtext")
                                }

                                Button {
                                    selectedIndex = index
                                    pasteItem(item, asPlainText: true)
                                } label: {
                                    Label("Paste as Plaintext", systemImage: "textformat")
                                }

                                Divider()

                                Button(role: .destructive) {
                                    historyManager.deleteItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onAppear {
                        // Reset selection and scroll to top when view appears
                        selectedIndex = -1
                        if let firstItem = filteredItems.first {
                            proxy.scrollTo(firstItem.id, anchor: .top)
                        }
                    }
                    .onChange(of: filteredItems) { _, newItems in
                        // Scroll to top when items change
                        if let firstItem = newItems.first {
                            proxy.scrollTo(firstItem.id, anchor: .top)
                        }
                        // Reset selection if current selection is out of bounds
                        if selectedIndex >= newItems.count {
                            selectedIndex = -1
                        }
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex >= 0 && newIndex < filteredItems.count {
                            withAnimation {
                                proxy.scrollTo(filteredItems[newIndex].id, anchor: .center)
                            }
                        }
                    }
                }
            }

            Divider()

            // Bottom toolbar
            ToolbarView(
                plainTextMode: $plainTextMode,
                showStarredOnly: $showStarredOnly,
                isPaused: $clipboardMonitor.isPaused,
                onDelete: {
                    deleteSelectedItem()
                },
                onSettings: onSettings
            )
        }
        .frame(minWidth: 280, minHeight: 300)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.return) {
            if selectedIndex < filteredItems.count {
                pasteItem(filteredItems[selectedIndex], asPlainText: plainTextMode)
            }
            return .handled
        }
        .onKeyPress(.delete) {
            deleteSelectedItem()
            return .handled
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
            if let number = Int(String(press.characters)), number >= 1, number <= 9 {
                let index = number - 1
                if index < filteredItems.count {
                    selectedIndex = index
                    pasteItem(filteredItems[index], asPlainText: plainTextMode)
                }
            }
            return .handled
        }
    }

    // MARK: - Actions

    private func moveSelection(by delta: Int) {
        guard !filteredItems.isEmpty else { return }

        if selectedIndex < 0 {
            // No selection - select first or last based on direction
            selectedIndex = delta > 0 ? 0 : filteredItems.count - 1
        } else {
            let newIndex = selectedIndex + delta
            if newIndex >= 0 && newIndex < filteredItems.count {
                selectedIndex = newIndex
            }
        }
    }

    private func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.itemType {
        case .text, .rtf:
            pasteboard.setString(item.textContent ?? "", forType: .string)
        case .image:
            if let imageData = item.imageData {
                pasteboard.setData(imageData, forType: .png)
            }
        case .file:
            if let urls = item.fileURLs {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }

        // Move item to top without dismissing or pasting
        historyManager.moveToTop(item)
    }

    private func pasteItem(_ item: ClipboardItem, asPlainText: Bool) {
        print("📋 Pasting item: \(item.previewText.prefix(50))... (plainText: \(asPlainText))")

        // Write to pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.itemType {
        case .text, .rtf:
            if asPlainText {
                // Strip formatting and paste as plain text
                pasteboard.setString(item.textContent ?? "", forType: .string)
            } else {
                pasteboard.setString(item.textContent ?? "", forType: .string)
            }

        case .image:
            if let imageData = item.imageData {
                pasteboard.setData(imageData, forType: .png)
            }

        case .file:
            if let urls = item.fileURLs {
                pasteboard.writeObjects(urls as [NSURL])
            }
        }

        // Update item's position (move to top)
        historyManager.moveToTop(item)

        // Reset selection so next open doesn't highlight wrong item
        selectedIndex = -1

        // Dismiss panel first, then paste
        onDismiss()

        // Simulate paste after panel closes
        simulatePaste()
    }

    private func simulatePaste() {
        // Check accessibility permission first
        guard AccessibilityHelper.hasPermission else {
            print("⚠️ Paste failed: No accessibility permission. Please add PestoClipboard to System Settings > Privacy & Security > Accessibility")
            return
        }

        // Delay to let panel dismiss and previous app regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Maccy-style paste implementation
            // Add 0x000008 flag for left/right modifier key detection
            let cmdFlag = CGEventFlags(rawValue: UInt64(CGEventFlags.maskCommand.rawValue) | 0x000008)

            let source = CGEventSource(stateID: .combinedSessionState)
            // Disable local keyboard events while pasting
            source?.setLocalEventsFilterDuringSuppressionState(
                [.permitLocalMouseEvents, .permitSystemDefinedEvents],
                state: .eventSuppressionStateSuppressionInterval
            )

            // Virtual key code for 'V' is 0x09
            let vKeyCode: CGKeyCode = 0x09

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false)
            keyDown?.flags = cmdFlag
            keyUp?.flags = cmdFlag
            keyDown?.post(tap: .cgSessionEventTap)
            keyUp?.post(tap: .cgSessionEventTap)

            print("✅ Paste event posted successfully")
        }
    }

    private func deleteSelectedItem() {
        guard selectedIndex >= 0, selectedIndex < filteredItems.count else { return }

        let item = filteredItems[selectedIndex]
        historyManager.deleteItem(item)

        // Adjust selection
        if selectedIndex >= filteredItems.count && selectedIndex > 0 {
            selectedIndex = filteredItems.count - 1
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let itemCount: Int

    var body: some View {
        HStack {
            Text("Pesto Clipboard")
                .font(.system(size: 13, weight: .semibold))

            Text("(\(itemCount))")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No clipboard history")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Copy something to get started")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Search Empty State View

struct SearchEmptyStateView: View {
    let query: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No results found")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("No items matching \"\(query)\"")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Starred Empty State View

struct StarredEmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "star")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)

            Text("No starred items")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Star items to keep them safe")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let historyManager = ClipboardHistoryManager()
    let clipboardMonitor = ClipboardMonitor(historyManager: historyManager)
    return HistoryView(
        historyManager: historyManager,
        clipboardMonitor: clipboardMonitor,
        onDismiss: {},
        onSettings: {}
    )
}
