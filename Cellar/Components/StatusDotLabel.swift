import SwiftUI

/// A status dot with its label, so state never depends on color alone.
/// While `isBusy`, a spinner takes the dot's place.
struct StatusDotLabel: View {
    let text: String
    let color: Color
    var isBusy = false

    var body: some View {
        HStack(spacing: Spacing.related) {
            if isBusy {
                ProgressView()
                    .controlSize(.mini)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: IconSize.statusDot, height: IconSize.statusDot)
                    .accessibilityHidden(true)
            }
            Text(text)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.item) {
        StatusDotLabel(text: "Running", color: .green)
        StatusDotLabel(text: "Stopped", color: .secondary)
        StatusDotLabel(text: "Running", color: .green, isBusy: true)
    }
    .padding()
}
