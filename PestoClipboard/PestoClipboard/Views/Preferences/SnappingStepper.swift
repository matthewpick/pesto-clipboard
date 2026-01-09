import SwiftUI

/// A stepper that snaps values to multiples of the step size
struct SnappingStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                let newValue = ((value - 1) / step) * step
                value = max(newValue, range.lowerBound)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 22, height: 18)
            }
            .disabled(value <= range.lowerBound)

            Divider()
                .frame(height: 14)

            Button {
                let newValue = ((value / step) + 1) * step
                value = min(newValue, range.upperBound)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 22, height: 18)
            }
            .disabled(value >= range.upperBound)
        }
        .buttonStyle(.borderless)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color(nsColor: .tertiaryLabelColor), lineWidth: 0.5)
        )
    }
}
