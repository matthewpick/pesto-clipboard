import SwiftUI

struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to Pesto Clipboard")
                .font(.title)
                .fontWeight(.bold)

            Text("Your clipboard history, always at your fingertips.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(icon: "clock.arrow.circlepath", text: "Access your clipboard history anytime")
                FeatureRow(icon: "keyboard", text: "Quick access with a keyboard shortcut")
                FeatureRow(icon: "star.fill", text: "Star items to keep them forever")
                FeatureRow(icon: "pause.fill", text: "Pause clipboard capturing")
                FeatureRow(icon: "textformat", text: "Toggle plaintext mode")
            }
            .padding(.top, 16)
        }
        .padding(32)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(Color.accentColor)
            Text(text)
        }
    }
}

#Preview {
    WelcomeStepView()
        .frame(width: 480, height: 320)
}
