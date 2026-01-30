import SwiftUI
import CellarCore

struct LoadingView: View {
    var message: String = "Loading…"

    var body: some View {
        ContentUnavailableView {
            ProgressView()
                .controlSize(.large)
        } description: {
            Text(message)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    LoadingView()
}

#Preview("Custom Message") {
    LoadingView(message: "Fetching formulae…")
}
