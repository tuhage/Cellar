import SwiftUI

/// The toolbar's refresh button. Pages name what it does — "Reload" for
/// local lists, "Check for Updates" when it runs `brew update`.
struct RefreshToolbarButton: View {
    var title = "Refresh"
    var systemImage = "arrow.clockwise"
    /// Tooltip; defaults to the title. Say what the button fetches when
    /// pages refresh different things.
    var help: String?
    var isLoading: Bool
    var action: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: systemImage)
                .symbolEffect(.rotate, isActive: isLoading && !reduceMotion)
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
