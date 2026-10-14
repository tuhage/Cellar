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

    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        ForEach(actions.filter { $0.isAvailable(for: service) }) { action in
            ServiceActionButton(action: action, service: service, pending: $pending)
        }
        .disabled(activityStore.isActive(.package(service.name)))
    }
}

// MARK: - Confirmation

extension View {
    /// Asks before running the destructive service action in `pending`.
    func confirmingServiceAction(_ pending: Binding<PendingServiceAction?>) -> some View {
        modifier(ServiceActionConfirmation(pending: pending))
    }
}

private struct ServiceActionConfirmation: ViewModifier {
    @Binding var pending: PendingServiceAction?
    @Environment(ServiceStore.self) private var store

    func body(content: Content) -> some View {
        content.confirmationDialog(
            pending.map { "\($0.action.confirmationVerb) \($0.service.name)?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { pending in
            buttons(for: pending)
        } message: { pending in
            Text(message(for: pending))
        }
    }

    @ViewBuilder
    private func buttons(for pending: PendingServiceAction) -> some View {
        let service = pending.service
        switch pending.action {
        case .forceQuit:
            Button("Force Quit", role: .destructive) {
                Task { await store.forceQuit(service) }
            }
            if service.keepsAlive {
                Button("Stop Instead") {
                    Task { await store.stop(service) }
                }
            }
        case .uninstall:
            Button("Uninstall", role: .destructive) {
                Task { await store.uninstall(service) }
            }
            Button("Uninstall Ignoring Dependencies", role: .destructive) {
                Task { await store.uninstall(service, force: true) }
            }
        default:
            EmptyView()
        }
        Button("Cancel", role: .cancel) {}
    }

    private func message(for pending: PendingServiceAction) -> String {
        let service = pending.service
        let password = service.requiresRoot ? " You’ll be asked for your administrator password." : ""
        switch pending.action {
        case .forceQuit:
            let relaunch = service.keepsAlive
                ? " launchd will start it again right away because it’s set to keep running; use Stop to stop it for good."
                : ""
            return "\(service.name) is killed immediately, without a chance to save data or clean up.\(relaunch)\(password)"
        default:
            return "This stops \(service.name) and removes the formula from Homebrew. Its data and logs are kept.\(password)"
        }
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
