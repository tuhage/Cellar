import SwiftUI

extension View {
    /// The page's refresh: a toolbar button and ⌘R, both running `action`.
    /// Name what it does — "Reload" for local lists, "Check for Updates"
    /// when it runs `brew update`.
    ///
    /// - Parameter help: Tooltip; defaults to the title. Say what the button
    ///   fetches when pages refresh different things.
    func pageRefresh(
        _ title: String = "Reload",
        systemImage: String = "arrow.clockwise",
        help: String? = nil,
        isLoading: Bool,
        action: @escaping @MainActor () async -> Void
    ) -> some View {
        toolbar {
            ToolbarItem(placement: .primaryAction) {
                RefreshToolbarButton(title: title, systemImage: systemImage, help: help, isLoading: isLoading, action: action)
            }
        }
        .focusedSceneValue(\.pageRefresh, AsyncAction(action: action))
    }
}

private struct RefreshToolbarButton: View {
    let title: String
    let systemImage: String
    let help: String?
    let isLoading: Bool
    let action: @MainActor () async -> Void

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
    NavigationStack {
        Text("Page")
            .pageRefresh(isLoading: false) {}
    }
    .frame(width: 400, height: 200)
}

#Preview("Loading") {
    NavigationStack {
        Text("Page")
            .pageRefresh(isLoading: true) {}
    }
    .frame(width: 400, height: 200)
}
