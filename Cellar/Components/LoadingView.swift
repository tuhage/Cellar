import SwiftUI
import CellarCore

struct LoadingView: View {
    var message: String = "Loading…"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: Spacing.sectionContent) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.secondary)
                .opacity(isPulsing && !reduceMotion ? 0.6 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: isPulsing
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
        .onAppear { isPulsing = !reduceMotion }
    }
}

#Preview {
    LoadingView()
}

#Preview("Custom Message") {
    LoadingView(message: "Fetching formulae…")
}
