import SwiftUI

// MARK: - Keyboard Handlers Extension

extension View {
    func historyKeyboardHandlers(
        viewModel: HistoryViewModel,
        focusedField: FocusState<HistoryView.FocusField?>.Binding,
        isSearchFocused: Bool,
        onDismiss: @escaping () -> Void
    ) -> some View {
        self
            .onKeyPress(.upArrow) {
                if viewModel.selectedIndex == 0 {
                    focusedField.wrappedValue = .search
                } else {
                    focusedField.wrappedValue = .list
                    viewModel.moveSelection(by: -1)
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                if isSearchFocused {
                    focusedField.wrappedValue = .list
                    viewModel.selectedIndex = 0
                } else {
                    viewModel.moveSelection(by: 1)
                }
                return .handled
            }
            .onKeyPress(.return) {
                viewModel.pasteSelectedItem(
                    asPlainText: viewModel.settings.plainTextMode,
                    onDismiss: onDismiss
                )
                return .handled
            }
            .onKeyPress(.delete) {
                guard !isSearchFocused else { return .ignored }
                viewModel.deleteSelectedItem()
                return .handled
            }
            .onKeyPress(.deleteForward) {
                guard !isSearchFocused else { return .ignored }
                viewModel.deleteSelectedItem()
                return .handled
            }
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
            .onKeyPress(keys: ["f"]) { press in
                if press.modifiers.contains(.command) {
                    focusedField.wrappedValue = .search
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
                guard !isSearchFocused else { return .ignored }

                if let number = Int(String(press.characters)), number >= 1, number <= 9 {
                    viewModel.pasteItemAtIndex(
                        number - 1,
                        asPlainText: viewModel.settings.plainTextMode,
                        onDismiss: onDismiss
                    )
                }
                return .handled
            }
    }
}
