import SwiftUI

/// Toolbar button that exposes the activity panel via a popover. Shows a
/// pulse symbol with a badge counting running operations.
struct ActivityToolbarButton: View {
    @Environment(ActivityStore.self) private var store
    @State private var isPanelPresented = false

    var body: some View {
        Button {
            isPanelPresented.toggle()
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: store.runningCount > 0 ? "bolt.circle.fill" : "bolt.circle")
                    .font(.title3)
                    .foregroundStyle(store.runningCount > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                if store.runningCount > 0 {
                    Text("\(store.runningCount)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.red, in: Capsule())
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 28, height: 22)
        }
        .help(store.runningCount > 0 ? "\(store.runningCount) running" : "Activity")
        .popover(isPresented: $isPanelPresented, arrowEdge: .top) {
            ActivityPanel()
                .environment(store)
        }
    }
}

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
