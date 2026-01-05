import SwiftUI

struct SearchBar<FocusValue: Hashable>: View {
    @Binding var text: String
    var focusBinding: FocusState<FocusValue?>.Binding
    var focusValue: FocusValue

    private var isFocused: Bool {
        focusBinding.wrappedValue == focusValue
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(focusBinding, equals: focusValue)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
        }
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
        }
    }
}
