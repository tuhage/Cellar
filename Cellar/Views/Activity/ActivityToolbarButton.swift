import SwiftUI

/// Toolbar button that opens the Activity panel. A badge counts running
/// operations, or failures once nothing runs.
struct ActivityToolbarButton: View {
    @Environment(ActivityStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPanelPresented = false

    var body: some View {
        Button {
            isPanelPresented.toggle()
        } label: {
            Image(systemName: store.runningCount > 0 ? "clock.arrow.circlepath" : "clock")
                .font(.title3)
                .foregroundStyle(iconTint)
                .symbolEffect(.rotate, isActive: store.runningCount > 0 && !reduceMotion)
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        CountBadge(count: badge.count, tint: badge.color, style: .filled)
                            .offset(x: Spacing.item, y: -Spacing.compact)
                    }
                }
        }
        .help(summary)
        .accessibilityLabel("Activity")
        .accessibilityValue(summary)
        .popover(isPresented: $isPanelPresented, arrowEdge: .top) {
            ActivityPanel()
                .frame(width: 380, height: 480)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openActivityPanel)) { _ in
            isPanelPresented = true
        }
    }

    private var badge: (count: Int, color: Color)? {
        if store.runningCount > 0 { return (store.runningCount, .accentColor) }
        if store.failedCount > 0 { return (store.failedCount, .red) }
        return nil
    }

    private var iconTint: Color {
        if store.runningCount > 0 { return .accentColor }
        if store.failedCount > 0 { return .red }
        return .secondary
    }

    private var summary: String {
        switch (store.runningCount, store.failedCount) {
        case (0, 0): "No operations need attention"
        case (let running, 0): "\(running) running"
        case (0, let failed): "\(failed) failed"
        case (let running, let failed): "\(running) running, \(failed) failed"
        }
    }
}

extension Notification.Name {
    static let openActivityPanel = Notification.Name("cellar.openActivityPanel")
}

// MARK: - Previews

#Preview("Idle") {
    ActivityToolbarButton()
        .environment(AppStores())
        .padding()
}

#Preview("Running") {
    ActivityToolbarButton()
        .environment(ActivityStore.preview([.upgradeAllPreview]))
        .padding()
}

#Preview("Mixed") {
    ActivityToolbarButton()
        .environment(ActivityStore.preview(BrewOperation.previewList))
        .padding()
}
