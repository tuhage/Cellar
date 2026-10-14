import SwiftUI
import CellarCore

/// A button for a `ServiceAction`. Reversible actions run at once;
/// destructive ones go to `pending` for `confirmingServiceAction(_:)`.
struct ServiceActionButton: View {
    let action: ServiceAction
    let service: BrewServiceItem
    @Binding var pending: PendingServiceAction?

    @Environment(ServiceStore.self) private var store

    var body: some View {
        Button(role: action.isDestructive ? .destructive : nil) {
            if action.isDestructive {
                pending = PendingServiceAction(action: action, service: service)
            } else {
                Task { await action.perform(on: service, store: store) }
            }
        } label: {
            Label(action.title(for: service), systemImage: action.systemImage)
        }
        .help(action.help(for: service))
    }
}

/// Buttons for the actions that apply to the service now, disabled while
/// one of its actions runs.
struct ServiceActionButtons: View {
    let actions: [ServiceAction]
    let service: BrewServiceItem
    @Binding var pending: PendingServiceAction?

    @Environment(ServiceStore.self) private var store

    var body: some View {
        ForEach(actions.filter { $0.isAvailable(for: service) }) { action in
            ServiceActionButton(action: action, service: service, pending: $pending)
        }
        .disabled(store.isBusy(service))
    }
}

// MARK: - Confirmation

extension View {
    /// Asks before running the destructive service action in `pending`.
    /// Uninstall uses the package pages' confirmation, which also warns
    /// about formulae that still need the service's formula.
    func confirmingServiceAction(_ pending: Binding<PendingServiceAction?>) -> some View {
        modifier(ServiceActionConfirmation(pending: pending))
    }
}

private struct ServiceActionConfirmation: ViewModifier {
    @Binding var pending: PendingServiceAction?
    @State private var uninstallRequest: UninstallRequest?

    @Environment(ServiceStore.self) private var store
    @Environment(PackageStore.self) private var packageStore

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                pending.map { "Force quit \($0.service.name)?" } ?? "",
                isPresented: Binding(get: { pending?.action == .forceQuit }, set: { if !$0 { pending = nil } }),
                titleVisibility: .visible,
                presenting: pending
            ) { pending in
                forceQuitButtons(for: pending.service)
            } message: { pending in
                Text(forceQuitMessage(for: pending.service))
            }
            .uninstallConfirmation($uninstallRequest)
            .onChange(of: pending?.id) {
                guard let pending, pending.action == .uninstall else { return }
                self.pending = nil
                let formula = packageStore.package(PackageID(kind: .formula, name: pending.service.name))
                uninstallRequest = formula.map { UninstallRequest(packages: [$0]) }
            }
    }

    @ViewBuilder
    private func forceQuitButtons(for service: BrewServiceItem) -> some View {
        Button("Force Quit", role: .destructive) {
            Task { await store.forceQuit(service) }
        }
        if service.keepsAlive {
            Button("Stop Instead") {
                Task { await store.stop(service) }
            }
        }
        Button("Cancel", role: .cancel) {}
    }

    private func forceQuitMessage(for service: BrewServiceItem) -> String {
        let password = service.requiresRoot ? " You’ll be asked for your administrator password." : ""
        let relaunch = service.keepsAlive
            ? " launchd will start it again right away because it’s set to keep running; use Stop to stop it for good."
            : ""
        return "\(service.name) is killed immediately, without a chance to save data or clean up.\(relaunch)\(password)"
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var pending: PendingServiceAction?

    HStack {
        ServiceActionButtons(actions: ServiceAction.allCases, service: .preview, pending: $pending)
    }
    .buttonStyle(.bordered)
    .padding()
    .confirmingServiceAction($pending)
    .environment(AppStores())
}
