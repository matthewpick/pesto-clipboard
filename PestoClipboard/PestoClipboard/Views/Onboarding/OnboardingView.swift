import SwiftUI
import KeyboardShortcuts

enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case hotkey = 1
    case autoPaste = 2
}

struct OnboardingView: View {
    @State private var currentStep: OnboardingStep = .welcome
    @ObservedObject private var settings = SettingsManager.shared
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            Group {
                switch currentStep {
                case .welcome:
                    WelcomeStepView()
                case .hotkey:
                    HotkeyStepView()
                case .autoPaste:
                    AutoPasteStepView(pasteAutomatically: $settings.pasteAutomatically, launchAtLogin: $settings.launchAtLogin)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // Navigation footer
            OnboardingFooterView(
                currentStep: $currentStep,
                onComplete: {
                    settings.hasCompletedOnboarding = true
                    onComplete()
                }
            )
        }
        .frame(width: 480, height: 540)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
