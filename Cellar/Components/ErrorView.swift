import SwiftUI

struct ErrorView: View {
    let message: String
    var retryAction: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label("Something Went Wrong", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            if let retryAction {
                Button("Retry", action: retryAction)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

#Preview {
    ErrorView(message: "Could not connect to Homebrew.")
}

#Preview("With Retry") {
    ErrorView(message: "Failed to load formulae.") {
        print("Retrying…")
    }
}
