import SwiftUI
import KeyboardShortcuts

struct HotkeyStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)

            Text("Set Your Hotkey")
                .font(.title2)
                .fontWeight(.bold)

            Text("Choose a keyboard shortcut to quickly open your clipboard history from anywhere.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 8) {
                Text("Keyboard Shortcut")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                KeyboardShortcuts.Recorder(for: .openHistory)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 16)

            Text("Default: Cmd + Shift + V")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(32)
    }
}

#Preview {
    HotkeyStepView()
        .frame(width: 480, height: 320)
}
