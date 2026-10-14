import SwiftUI

/// Toolbar button that exposes the activity panel via a popover. Shows a
/// activity symbol with a badge for running or failed operations. Completed
/// operations stay available in the panel without permanently cluttering the
/// toolbar.
struct ActivityToolbarButton: View {
    @Environment(ActivityStore.self) private var store
    @State private var isPanelPresented = false

    var body: some View {
        Button {
            isPanelPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: hasAttention ? "clock.arrow.circlepath" : "clock")
                    .font(.title3)
                    .foregroundStyle(iconTint)
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(badgeColor, in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 28, height: 22)
        }
        .help(helpText)
        .popover(isPresented: $isPanelPresented, arrowEdge: .top) {
            ActivityPanel()
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openActivityPanel)) { _ in
            isPanelPresented = true
        }
    }

    // MARK: - Derived state

    private var hasOps: Bool { !store.operations.isEmpty }

    private var failedCount: Int {
        store.operations.filter {
            if case .failed = $0.status { return true }
            return false
        }.count
    }

    private var badgeCount: Int { store.runningCount + failedCount }
    private var hasAttention: Bool { badgeCount > 0 }

    private var hasFailures: Bool {
        store.operations.contains {
            if case .failed = $0.status { return true }
            return false
        }
    }

    private var iconTint: AnyShapeStyle {
        if store.runningCount > 0 {
            return AnyShapeStyle(.tint)
        } else if hasFailures {
            return AnyShapeStyle(.red)
        } else if hasOps {
            return AnyShapeStyle(.primary)
        } else {
            return AnyShapeStyle(.secondary)
        }
    }

    private var badgeColor: Color {
        if store.runningCount > 0 { return .accentColor }
        if hasFailures { return .red }
        return .secondary
    }

    private var helpText: String {
        let running = store.runningCount
        if running > 0 {
            return "\(running) running"
        } else if hasFailures {
            return "\(failedCount) failed — click to review"
        } else if hasOps {
            return "Activity history"
        } else {
            return "Activity"
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
