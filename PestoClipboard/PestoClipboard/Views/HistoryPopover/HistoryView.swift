import SwiftUI

struct HistoryView: View {
    enum FocusField {
        case list
        case search
    }

    @StateObject private var viewModel: HistoryViewModel
    @FocusState private var focusedField: FocusField?

    let onDismiss: () -> Void
    let onSettings: () -> Void

    init(
        historyManager: ClipboardHistoryManager,
        clipboardMonitor: ClipboardMonitor,
        onDismiss: @escaping () -> Void,
        onSettings: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(
            historyManager: historyManager,
            clipboardMonitor: clipboardMonitor
        ))
        self.onDismiss = onDismiss
        self.onSettings = onSettings
    }

    private var isSearchFocused: Bool {
        focusedField == .search
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(itemCount: viewModel.filteredItems.count)

            SearchBar(
                text: $viewModel.searchText,
                focusBinding: $focusedField,
                focusValue: FocusField.search
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            historyContent

            Divider()

            ToolbarView(
                plainTextMode: $viewModel.settings.plainTextMode,
                showStarredOnly: $viewModel.showStarredOnly,
                isPaused: $viewModel.clipboardMonitor.isPaused,
                onDelete: { viewModel.deleteSelectedItem() },
                onSettings: onSettings
            )
        }
        .frame(minWidth: 280, minHeight: 300)
        .background(backgroundStyle)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .focusable()
        .focusEffectDisabled()
        .focused($focusedField, equals: .list)
        .onReceive(NotificationCenter.default.publisher(for: .showHistoryPanel)) { _ in
            focusedField = .list
            viewModel.onPanelShow()
        }
        .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedItem)) { _ in
            guard !isSearchFocused else { return }
            viewModel.deleteSelectedItem()
        }
        .historyKeyboardHandlers(
            viewModel: viewModel,
            focusedField: $focusedField,
            isSearchFocused: isSearchFocused,
            onDismiss: onDismiss
        )
        .onChange(of: viewModel.itemToEdit) { _, newItem in
            if let item = newItem {
                EditWindowController.shared.showEditWindow(
                    for: item,
                    historyManager: viewModel.historyManager
                )
                viewModel.itemToEdit = nil
            }
        }
        .alert(
            "Error",
            isPresented: errorAlertBinding,
            presenting: viewModel.historyManager.lastError
        ) { _ in
            Button("OK") { viewModel.clearError() }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var historyContent: some View {
        if viewModel.filteredItems.isEmpty {
            emptyStateView
        } else {
            HistoryListView(
                viewModel: viewModel,
                isSearchFocused: isSearchFocused,
                onDismiss: onDismiss
            )
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if !viewModel.searchText.isEmpty {
            SearchEmptyStateView(query: viewModel.searchText)
        } else if viewModel.showStarredOnly {
            StarredEmptyStateView()
        } else {
            EmptyStateView()
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        if viewModel.settings.useTransparentBackground {
            AnyShapeStyle(.regularMaterial)
        } else {
            AnyShapeStyle(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.hasError },
            set: { if !$0 { viewModel.clearError() } }
        )
    }
}

// MARK: - Preview

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
