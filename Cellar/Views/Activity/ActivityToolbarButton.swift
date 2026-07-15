import SwiftUI

/// Toolbar button that exposes the activity panel via a popover. Shows a
/// bolt symbol with a badge counting all tracked operations (running +
/// completed + failed). The icon stays filled and the badge visible as long
/// as there are any operations in the store, so the user knows there are
/// completed or failed items to review.
struct ActivityToolbarButton: View {
    @Environment(ActivityStore.self) private var store
    @State private var isPanelPresented = false

    var body: some View {
        Button {
            isPanelPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: hasOps ? "bolt.circle.fill" : "bolt.circle")
                    .font(.title3)
                    .foregroundStyle(iconTint)
                if hasOps {
                    Text("\(store.operations.count)")
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
        } else if hasOps {
            return "\(store.operations.count) finished — click to view"
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
        .environment(ActivityStore())
        .padding()
}

#Preview("Running") {
    let store = ActivityStore()
    _ = store.register(kind: .upgrade(name: "openssl@3", isCask: false))
    _ = store.register(kind: .upgradeAll(count: 33))
    return ActivityToolbarButton()
        .environment(store)
        .padding()
}

#Preview("Failed") {
    let store = ActivityStore()
    let id = store.register(kind: .upgrade(name: "ffmpeg", isCask: false))
    store.setStatus(id, .failed(reason: "Build error"))
    return ActivityToolbarButton()
        .environment(store)
        .padding()
}

#Preview("Completed Only") {
    let store = ActivityStore()
    let id = store.register(kind: .install(name: "ripgrep", isCask: false))
    store.setStatus(id, .succeeded)
    return ActivityToolbarButton()
        .environment(store)
        .padding()
}
