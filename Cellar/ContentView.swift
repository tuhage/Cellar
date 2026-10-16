import SwiftUI
import CellarCore

struct ContentView: View {
    @AppStorage(SettingsKey.selectedSidebarItem) private var storedSelection: String = SidebarItem.dashboard.rawValue

    private var selection: Binding<SidebarItem?> {
        Binding(
            get: { SidebarItem.resolve(storedSelection) ?? .dashboard },
            set: { newValue in storedSelection = (newValue ?? .dashboard).rawValue }
        )
    }
    @State private var isBrewInstalled = BrewProcess.isInstalled
    @State private var isQuickOpenPresented = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PackageStore.self) private var packageStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @Environment(ActivityStore.self) private var activityStore
    @Environment(\.refreshAll) private var refreshAll
    @Environment(\.openWindow) private var openWindow
    @Environment(\.startBackgroundWork) private var startBackgroundWork

    var body: some View {
        Group {
            if isBrewInstalled {
                mainContent
            } else {
                OnboardingView {
                    withAnimation { isBrewInstalled = true }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            guard !isBrewInstalled else { return }
            isBrewInstalled = BrewProcess.isInstalled
        }
        .task(id: isBrewInstalled) {
            guard isBrewInstalled else { return }
            await startBackgroundWork()
        }
    }

    private var mainContent: some View {
        @Bindable var packages = packageStore
        @Bindable var maintenance = maintenanceStore

        return NavigationSplitView {
            SidebarView(selection: selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            if let item = selection.wrappedValue {
                DetailView(item: item)
                    .defaultOperationNotice()
            } else {
                EmptyStateView(
                    title: "Select an Item",
                    systemImage: "sidebar.left",
                    description: "Choose a section from the sidebar."
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    isQuickOpenPresented = true
                } label: {
                    Image(systemName: "command.square")
                }
                .help("Quick Open (⌘K)")
                .accessibilityLabel("Quick Open")
            }

            ToolbarItem(placement: .secondaryAction) {
                ActivityToolbarButton()
            }
        }
        .sheet(isPresented: $packages.isUpgradePreviewPresented) {
            UpgradeAllSheet()
        }
        .sheet(isPresented: $maintenance.isCleanupPreviewPresented) {
            CleanupPreviewSheet()
        }
        .sheet(isPresented: $maintenance.isAutoremovePreviewPresented) {
            AutoremovePreviewSheet()
        }
        .overlay {
            if isQuickOpenPresented {
                quickOpen
            }
        }
        .animation(reduceMotion ? nil : AnimationToken.snap, value: isQuickOpenPresented)
        .urlSchemeHandler()
        .focusedSceneValue(\.windowCommands, windowCommands)
    }

    /// A Spotlight-style panel over the window; clicking outside closes it.
    private var quickOpen: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(Opacity.pressedOverlay)
                .ignoresSafeArea()
                .onTapGesture { isQuickOpenPresented = false }
                .accessibilityHidden(true)

            QuickOpenView(isPresented: $isQuickOpenPresented)
                .frame(width: 580, height: 460)
                .floatingSurface(cornerRadius: CornerRadius.extraLarge)
                .padding(.top, Spacing.section * 3)
        }
        .transition(.opacity)
    }

    private var windowCommands: WindowCommands {
        WindowCommands(
            navigate: Navigator.show,
            openQuickOpen: { isQuickOpenPresented = true },
            showActivity: { openWindow(id: SceneID.activity) },
            refreshAll: refreshAll,
            canUpgradeAll: packageStore.canUpgradeAll,
            previewUpgradeAll: { packageStore.isUpgradePreviewPresented = true },
            canCleanUp: !maintenanceStore.isRunning,
            previewCleanup: { maintenanceStore.isCleanupPreviewPresented = true },
            canCheckForUpdates: !activityStore.isActive(.homebrew),
            checkForPackageUpdates: { Task { await packageStore.checkForUpdates() } }
        )
    }
}

private struct DetailView: View {
    let item: SidebarItem

    var body: some View {
        switch item {
        case .dashboard:
            DashboardView()
        case .formulae:
            PackageListPage(kind: .formula)
        case .casks:
            PackageListPage(kind: .cask)
        case .services:
            ServiceListView()
        case .outdated:
            OutdatedView()
        case .brewfile:
            BrewfileView()
        case .taps:
            TapListView()
        case .dependencies:
            DependencyGraphView()
        case .maintenance:
            MaintenanceView()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppStores())
}
