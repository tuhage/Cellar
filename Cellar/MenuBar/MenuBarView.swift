import SwiftUI

// MARK: - MenuBarView

/// The content displayed inside the menu bar extra dropdown.
///
/// Reads from the shared `PackageStore` and `ServiceStore` to show
/// running services, available updates, and quick actions. All heavy
/// lifting happens through the existing stores — this view is
/// intentionally lightweight.
struct MenuBarView: View {
    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(MaintenanceStore.self) private var maintenanceStore

    var body: some View {
        headerSection
        Divider()
        servicesSection
        Divider()
        updatesSection
        Divider()
        actionsSection
        Divider()
        appSection
    }

    // MARK: - Header

    private var headerSection: some View {
        Group {
            Text("Cellar \(appVersion)")
                .font(.headline)
            Text("\(packageStore.formulae.count) formulae, \(packageStore.casks.count) casks")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Services

    @ViewBuilder
    private var servicesSection: some View {
        let running = serviceStore.runningServices

        if running.isEmpty {
            Label("No Running Services", systemImage: "stop.circle")
                .disabled(true)
        } else {
            Text("\(running.count) Running Service\(running.count == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(running) { service in
                Button {
                    Task { await serviceStore.stop(service) }
                } label: {
                    Label(service.name, systemImage: "stop.fill")
                }
            }
        }
    }

    // MARK: - Updates

    @ViewBuilder
    private var updatesSection: some View {
        let outdated = packageStore.totalOutdated

        if outdated == 0 {
            Label("Everything Up to Date", systemImage: "checkmark.circle")
                .disabled(true)
        } else {
            Label(
                "\(outdated) Update\(outdated == 1 ? "" : "s") Available",
                systemImage: "arrow.up.circle"
            )
            .disabled(true)

            Button("Upgrade All") {
                Task { await packageStore.upgradeAll() }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        Group {
            Button("Cleanup") {
                Task { await maintenanceStore.runCleanup() }
            }

            Button("Refresh") {
                Task {
                    await packageStore.loadAll()
                    await serviceStore.load()
                }
            }
        }
    }

    // MARK: - App Controls

    private var appSection: some View {
        Group {
            Button("Open Cellar") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }
            .keyboardShortcut("o")

            Divider()

            Button("Quit Cellar") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environment(PackageStore())
        .environment(ServiceStore())
        .environment(MaintenanceStore())
}
