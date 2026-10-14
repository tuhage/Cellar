import SwiftUI
import AppKit

/// Cancels a running operation. Cancelling stops brew at once, so a batch
/// (Upgrade All) asks first; a single operation stops right away.
struct CancelOperationButton<Label: View>: View {
    let operation: BrewOperation
    @ViewBuilder let label: Label

    @Environment(ActivityStore.self) private var store
    @State private var isConfirming = false

    var body: some View {
        Button(role: .cancel) {
            if operation.isBatch {
                isConfirming = true
            } else {
                store.cancel(operation.id)
            }
        } label: {
            label
        }
        .disabled(!store.canCancel(operation.id))
        .confirmationDialog(BatchCancellation.title, isPresented: $isConfirming) {
            Button(BatchCancellation.confirmTitle, role: .destructive) {
                store.cancel(operation.id)
            }
            Button(BatchCancellation.keepTitle, role: .cancel) {}
        } message: {
            Text(BatchCancellation.message)
        }
    }
}

extension CancelOperationButton where Label == Text {
    init(operation: BrewOperation) {
        self.init(operation: operation) { Text("Cancel") }
    }
}

// MARK: - Batch Cancellation

/// What stopping a batch asks, shared by the dialog above and the menu bar,
/// which can't present SwiftUI dialogs.
enum BatchCancellation {
    static let title = "Stop Upgrading?"
    static let message = "The package being upgraded now is interrupted; packages already upgraded stay upgraded."
    static let confirmTitle = "Stop Upgrading"
    static let keepTitle = "Keep Upgrading"

    /// Asks with an alert; for menus. Returns whether to stop.
    @MainActor
    static func confirmWithAlert() -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: confirmTitle).hasDestructiveAction = true
        alert.addButton(withTitle: keepTitle)
        NSApplication.shared.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }
}

// MARK: - Preview

#Preview {
    HStack {
        CancelOperationButton(operation: .upgradeAllPreview)
        CancelOperationButton(operation: BrewOperation(kind: .install(name: "wget", isCask: false)))
    }
    .padding()
    .environment(AppStores(activity: .preview([.upgradeAllPreview])))
}
