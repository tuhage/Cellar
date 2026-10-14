import SwiftUI
import CellarCore

// MARK: - MenuBarView

/// The menu bar extra: services with their actions, resource use, updates
/// and maintenance — usable without opening the main window.
struct MenuBarView: View {
    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @Environment(ServiceMetricsStore.self) private var metrics
    @Environment(ActivityStore.self) private var activityStore
    @Environment(\.refreshAll) private var refreshAll
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if packageStore.lastUpdated == nil && serviceStore.lastUpdated == nil {
            Label("Loading\u{2026}", systemImage: "hourglass")
                .disabled(true)
        } else {
            servicesSection
            resourcesSection
            updatesSection
        }
        maintenanceSection
        appSection
    }

    // MARK: - Services

    @ViewBuilder
    private var servicesSection: some View {
        Section("Services") {
            let services = serviceStore.services.filter { $0.isRunning || $0.isError }
            if services.isEmpty {
                Text("No Running Services")
            } else {
                ForEach(services) { service in
                    serviceMenu(service)
                }
            }
        }
    }

    /// A submenu so a stray click never stops a service.
    private func serviceMenu(_ service: BrewServiceItem) -> some View {
        Menu {
            if service.isRunning {
                Button("Stop") { Task { await serviceStore.stop(service) } }
                Button("Restart") { Task { await serviceStore.restart(service) } }
            } else {
                Button("Start") { Task { await serviceStore.start(service) } }
            }
            Divider()
            Button("Show in Cellar") {
                serviceStore.selectedServiceId = service.id
                show(.services)
            }
        } label: {
            Label(
                service.isError ? "\(service.name) — Failed" : service.name,
                systemImage: service.isError ? "exclamationmark.octagon" : "circle.fill"
            )
        }
        .disabled(activityStore.isActive(.package(service.name)))
    }

    // MARK: - Resources

    @ViewBuilder
    private var resourcesSection: some View {
        Section("Service Resources") {
            if metrics.usages.isEmpty {
                Text("Measuring\u{2026}")
            } else {
                Label("\(ResourceUsage.formattedCPU(metrics.totalCPU)) CPU", systemImage: "cpu")
                Label("\(ResourceUsage.formattedMemory(metrics.totalMemoryBytes)) Memory", systemImage: "memorychip")
            }
        }
        .disabled(true)
        .task(id: serviceStore.runningCount) {
            await metrics.refresh(for: serviceStore.services)
        }
    }

    // MARK: - Updates

    @ViewBuilder
    private var updatesSection: some View {
        Section("Updates") {
            if let operation = packageStore.upgradeAllOperation, operation.isRunning {
                Text(upgradeProgressTitle(operation))
                Button("Stop Upgrading\u{2026}") {
                    if BatchCancellation.confirmWithAlert() {
                        activityStore.cancel(operation.id)
                    }
                }
            } else if packageStore.totalOutdated == 0 {
                Text("Everything Up to Date")
            } else {
                Button("Upgrade \(packageStore.totalOutdated) \(packageStore.totalOutdated == 1 ? "Package" : "Packages")\u{2026}") {
                    show(nil)
                    packageStore.isUpgradePreviewPresented = true
                }
                .disabled(packageStore.isCheckingForUpdates)
            }

            Button(packageStore.isCheckingForUpdates ? "Checking for Package Updates\u{2026}" : "Check for Package Updates") {
                Task { await packageStore.checkForUpdates() }
            }
            .disabled(activityStore.isActive(.homebrew))
        }
    }

    private func upgradeProgressTitle(_ operation: BrewOperation) -> String {
        guard let step = operation.currentStep, let position = operation.currentStepNumber else {
            return "Upgrading Packages\u{2026}"
        }
        return "Upgrading \(step.name) (\(position) of \(operation.steps.count))"
    }

    // MARK: - Maintenance

    private var maintenanceSection: some View {
        Section {
            Button(maintenanceStore.runningTask?.kind == .cleanup ? "Cleaning Up\u{2026}" : "Clean Up\u{2026}") {
                show(nil)
                maintenanceStore.isCleanupPreviewPresented = true
            }
            .disabled(maintenanceStore.isRunning)

            Button("Refresh") {
                Task { await refreshAll() }
            }
        }
    }

    // MARK: - App Controls

    private var appSection: some View {
        Section {
            Button("Open Cellar") { show(nil) }
                .keyboardShortcut("o")
            Button("Quit Cellar") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
    }

    // MARK: - Helpers

    /// Brings the main window forward — reopening it if it was closed —
    /// optionally on a page.
    private func show(_ item: SidebarItem?) {
        if let item {
            UserDefaults.standard.set(item.rawValue, forKey: "selectedSidebarItem")
        }
        if let window = NSApplication.shared.cellarMainWindow {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: SceneID.main)
        }
        NSApplication.shared.activate()
    }
}

// MARK: - Menu Bar Icon

/// Fills the mug when something needs attention: updates or a failed service.
struct MenuBarIcon: View {
    let packageStore: PackageStore
    let serviceStore: ServiceStore

    var body: some View {
        let needsAttention = packageStore.totalOutdated > 0 || serviceStore.services.contains(where: \.isError)
        Image(systemName: needsAttention ? "mug.fill" : "mug")
            .accessibilityLabel(needsAttention ? "Cellar, needs attention" : "Cellar")
    }
}

// MARK: - Preview

#Preview {
    MenuBarView()
        .environment(AppStores())
}
