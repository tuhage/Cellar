import SwiftUI

struct RefreshToolbarButton: View {
    var isLoading: Bool
    var action: () async -> Void

    var body: some View {
        if isLoading {
            ProgressView()
                .controlSize(.small)
                .padding(.horizontal, 8)
        } else {
            Button {
                Task { await action() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
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
