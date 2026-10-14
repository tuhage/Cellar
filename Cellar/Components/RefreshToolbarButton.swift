import SwiftUI

struct RefreshToolbarButton: View {
    var title = "Refresh"
    var systemImage = "arrow.clockwise"
    /// Tooltip; defaults to the title. Say what the button fetches when
    /// pages refresh different things.
    var help: String?
    var isLoading: Bool
    var action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: isLoading ? "progress.indicator" : systemImage)
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(isLoading)
        .help(help ?? title)
    }
}

#Preview("Idle") {
    RefreshToolbarButton(isLoading: false) {}
        .padding()
}

#Preview("Loading") {
    RefreshToolbarButton(isLoading: true) {}
        .padding()
}
