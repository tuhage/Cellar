import SwiftUI
import CellarCore

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String?

    var body: some View {
        Group {
            if let description {
                ContentUnavailableView(title, systemImage: systemImage, description: Text(description))
            } else {
                ContentUnavailableView(title, systemImage: systemImage)
            }
        }
        .symbolEffect(.pulse)
        .transition(.opacity)
    }
}

#Preview {
    EmptyStateView(
        title: "No Formulae",
        systemImage: "shippingbox",
        description: "Install formulae using the search tab."
    )
}

#Preview("Without Description") {
    EmptyStateView(title: "No Results", systemImage: "magnifyingglass")
}
