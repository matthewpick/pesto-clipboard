import SwiftUI

// MARK: - Keyboard Handlers Extension

extension View {
    func historyKeyboardHandlers(
        viewModel: HistoryViewModel,
        focusedField: FocusState<HistoryView.FocusField?>.Binding,
        isSearchFocused: Bool,
        onDismiss: @escaping () -> Void
    ) -> some View {
        // Defers execution to avoid "publishing during view update" warnings
        func deferred(_ action: @escaping () -> Void) {
            DispatchQueue.main.async(execute: action)
        }

        return self
            .onKeyPress(.upArrow) {
                deferred {
                    if viewModel.selectedIndex == 0 {
                        focusedField.wrappedValue = .search
                    } else {
                        focusedField.wrappedValue = .list
                        viewModel.moveSelection(by: -1)
                    }
                }
                return .handled
            }
            .onKeyPress(.downArrow) {
                deferred {
                    if isSearchFocused {
                        focusedField.wrappedValue = .list
                        viewModel.selectedIndex = 0
                    } else {
                        viewModel.moveSelection(by: 1)
                    }
                }
                return .handled
            }
            .onKeyPress(.return) {
                deferred {
                    viewModel.pasteSelectedItem(
                        asPlainText: viewModel.settings.plainTextMode,
                        onDismiss: onDismiss
                    )
                }
                return .handled
            }
            .onKeyPress(.delete) {
                guard !isSearchFocused else { return .ignored }
                deferred { viewModel.deleteSelectedItem() }
                return .handled
            }
            .onKeyPress(.deleteForward) {
                guard !isSearchFocused else { return .ignored }
                deferred { viewModel.deleteSelectedItem() }
                return .handled
            }
            .onKeyPress(.escape) {
                deferred { onDismiss() }
                return .handled
            }
            .onKeyPress(keys: ["f"]) { press in
                guard press.modifiers.contains(.command) else { return .ignored }
                deferred { focusedField.wrappedValue = .search }
                return .handled
            }
            .onKeyPress(keys: ["1", "2", "3", "4", "5", "6", "7", "8", "9"]) { press in
                guard !isSearchFocused else { return .ignored }
                let characters = press.characters
                deferred {
                    if let number = Int(String(characters)), number >= 1, number <= 9 {
                        viewModel.pasteItemAtIndex(
                            number - 1,
                            asPlainText: viewModel.settings.plainTextMode,
                            onDismiss: onDismiss
                        )
                    }
                }
                return .handled
            }
    }
}
