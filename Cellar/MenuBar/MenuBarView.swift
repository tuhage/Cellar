import SwiftUI
import CellarCore

// MARK: - MenuBarView

/// The content displayed inside the menu bar extra dropdown.
///
/// Reads from the shared stores to show running services, their combined
/// resource usage, available updates, and quick actions.
struct MenuBarView: View {
    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @Environment(ResourceStore.self) private var resourceStore

    @State private var isLoadingResources = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        headerSection
            .task {
                await refreshResourceUsage()
            }
        Divider()
        servicesSection
        Divider()
        resourcesSection
        Divider()
        updatesSection
        Divider()
        actionsSection
        Divider()
        appSection
    }

    // MARK: - Resources

    @ViewBuilder
    private var resourcesSection: some View {
        Text("Service Resources")
            .font(.subheadline)
            .foregroundStyle(.secondary)

        if isLoadingResources && resourceStore.usages.isEmpty {
            Label("Measuring Usage…", systemImage: "gauge.with.dots.needle.33percent")
                .disabled(true)
        } else if resourceStore.usages.isEmpty {
            Label("Resource Usage Unavailable", systemImage: "gauge.with.dots.needle.33percent")
                .disabled(true)
        } else {
            Label(
                "\(formattedCPU(resourceStore.totalCPU)) CPU",
                systemImage: "cpu"
            )
            .disabled(true)

            Label(
                "\(formattedMemory(resourceStore.totalMemoryMB)) RAM",
                systemImage: "memorychip"
            )
            .disabled(true)
        }
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

        if packageStore.isUpgradingAll {
            Label(upgradeProgressTitle, systemImage: "arrow.up.circle")
                .disabled(true)

            Button("Cancel Upgrade") {
                packageStore.cancelUpgradeAll()
            }
        } else if outdated == 0 {
            Label("Everything Up to Date", systemImage: "checkmark.circle")
                .disabled(true)
        } else {
            Label(
                "\(outdated) Update\(outdated == 1 ? "" : "s") Available",
                systemImage: "arrow.up.circle"
            )
            .disabled(true)

            Button("Upgrade All\u{2026}") {
                showMainWindow()
                packageStore.isUpgradePreviewPresented = true
            }
            .disabled(packageStore.isCheckingForUpdates)
        }

        Button(packageStore.isCheckingForUpdates ? "Checking for Updates\u{2026}" : "Check for Updates") {
            Task { await packageStore.checkForUpdates() }
        }
        .disabled(packageStore.isCheckingForUpdates || packageStore.isUpgradingAll)
    }

    private var upgradeProgressTitle: String {
        guard let operation = packageStore.upgradeAllOperation,
              let step = operation.currentStep,
              let position = operation.currentStepNumber
        else { return "Upgrading Packages\u{2026}" }
        return "Upgrading \(step.name) (\(position) of \(operation.steps.count))"
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
                    await refreshResourceUsage()
                }
            }
        }
    }

    // MARK: - App Controls

    private var appSection: some View {
        Group {
            Button("Open Cellar") {
                showMainWindow()
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

    /// Brings the main window forward, reopening it if it was closed.
    private func showMainWindow() {
        openWindow(id: SceneID.main)
        NSApplication.shared.activate()
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func refreshResourceUsage() async {
        isLoadingResources = true
        await resourceStore.loadResourceUsage(for: serviceStore.services)
        isLoadingResources = false
    }

    private func formattedCPU(_ percent: Double) -> String {
        String(format: "%.1f%%", percent)
    }

    private func formattedMemory(_ megabytes: Double) -> String {
        if megabytes >= 1_024 {
            return String(format: "%.1f GB", megabytes / 1_024)
        }
        return String(format: megabytes < 10 ? "%.1f MB" : "%.0f MB", megabytes)
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environment(AppStores())
}
