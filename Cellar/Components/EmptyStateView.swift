import SwiftUI
import CellarCore

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String?
    var actionTitle: String?
    var actionSystemImage: String = "arrow.clockwise"
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            if let description {
                Text(description)
            }
        } actions: {
            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: actionSystemImage)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        // A grouped Form row lays a lone view out like a label, in the
        // leading column; filling the width keeps it centered there too.
        .frame(maxWidth: .infinity)
        .transition(.opacity)
    }
}

#Preview {
    EmptyStateView(
        title: "No Formulae",
        systemImage: "shippingbox",
        description: "Installed formulae will appear here."
    )
}

#Preview("Without Description") {
    EmptyStateView(title: "No Results", systemImage: "magnifyingglass")
}
