import SwiftUI

struct RefreshToolbarButton: View {
    var isLoading: Bool
    var action: () async -> Void

    var body: some View {
        Button {
            Task { await action() }
        } label: {
            Label("Refresh", systemImage: isLoading ? "progress.indicator" : "arrow.clockwise")
                .contentTransition(.symbolEffect(.replace))
        }
        .disabled(isLoading)
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
