import SwiftUI

struct OnboardingFooterView: View {
    @Binding var currentStep: OnboardingStep
    var onComplete: () -> Void

    private var isFirstStep: Bool {
        currentStep == .welcome
    }

    private var isLastStep: Bool {
        currentStep == .autoPaste
    }

    var body: some View {
        HStack {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 12) {
                if !isFirstStep {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .welcome
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if isLastStep {
                    Button("Get Started") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Next") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .autoPaste
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
