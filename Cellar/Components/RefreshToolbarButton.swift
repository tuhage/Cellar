import SwiftUI

/// The toolbar's refresh button. Pages name what it does — "Reload" for
/// local lists, "Check for Updates" when it runs `brew update`.
struct RefreshToolbarButton: View {
    var title: String = "Refresh"
    var help: String = "Reload this page"
    var isLoading: Bool
    var action: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: "arrow.clockwise")
                .symbolEffect(.rotate, isActive: isLoading && !reduceMotion)
        }
        .disabled(isLoading)
        .help(help)
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
