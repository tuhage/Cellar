import SwiftUI
import CellarCore

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        VStack(spacing: Spacing.item) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LoadingView()
}

#Preview("Custom Message") {
    LoadingView(message: "Fetching formulae…")
}
