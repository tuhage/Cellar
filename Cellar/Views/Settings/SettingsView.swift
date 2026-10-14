import SwiftUI
import FinderSync
import ServiceManagement
import UniformTypeIdentifiers
import UserNotifications
import CellarCore

struct SettingsView: View {
    @AppStorage(SettingsKey.selectedSettingsTab) private var selectedTab = SettingsTab.general.rawValue

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
                .tag(SettingsTab.general.rawValue)

            MaintenanceTab()
                .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver") }
                .tag(SettingsTab.maintenance.rawValue)

            ExtensionsTab()
                .tabItem { Label("Extensions", systemImage: "puzzlepiece.extension") }
                .tag(SettingsTab.extensions.rawValue)

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about.rawValue)
        }
        .frame(width: 540, height: 540)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @AppStorage(SettingsKey.showsMenuBarExtra) private var showsMenuBarExtra = true
    @AppStorage(SettingsKey.serviceRefreshInterval) private var refreshInterval = AppStores.defaultServiceRefreshInterval
    @AppStorage(SettingsKey.confirmsBeforeUninstall) private var confirmsBeforeUninstall = true
    @AppStorage(SettingsKey.checksPackageUpdatesDaily) private var checksPackageUpdatesDaily = true

    private static let refreshIntervals: [Double] = [10, 15, 30, 60]

    var body: some View {
        Form {
            Section {
                OpenAtLoginToggle()
                Toggle("Show Menu Bar Icon", isOn: $showsMenuBarExtra)
            }

            Section {
                Toggle("Check for Package Updates Daily", isOn: $checksPackageUpdatesDaily)
                Toggle("Confirm Before Uninstalling", isOn: $confirmsBeforeUninstall)
            } header: {
                Text("Packages")
            } footer: {
                Text("Runs `brew update` once a day so Updates lists the latest versions.")
            }

            Section {
                Picker("Refresh Status Every", selection: $refreshInterval) {
                    ForEach(Self.refreshIntervals, id: \.self) { seconds in
                        Text(Duration.seconds(seconds).formatted(.units(width: .wide))).tag(seconds)
                    }
                }
            } header: {
                Text("Services")
            } footer: {
                Text("Service status refreshes only while Cellar is the active app.")
            }

            NotificationsSection()
        }
        .formStyle(.grouped)
    }
}

// MARK: - Open at Login

private struct OpenAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled
    @State private var errorMessage: String?

    var body: some View {
        Toggle("Open at Login", isOn: Binding(get: { isEnabled }, set: setEnabled))
        if let errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func setEnabled(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isEnabled = SMAppService.mainApp.status == .enabled
    }
}

// MARK: - Notifications

private struct NotificationsSection: View {
    @AppStorage(SettingsKey.showsNotifications) private var showsNotifications = true
    @State private var status: UNAuthorizationStatus = .notDetermined

    private static let systemSettingsURL = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")

    var body: some View {
        Section {
            Toggle("Notify When Operations Finish", isOn: $showsNotifications)
                .onChange(of: showsNotifications) { _, enabled in
                    guard enabled else { return }
                    Task {
                        await ActivityNotificationService.shared.requestAuthorizationIfNeeded()
                        await refreshStatus()
                    }
                }

            if showsNotifications, status == .denied {
                LabeledContent {
                    if let url = Self.systemSettingsURL {
                        Link("Open System Settings", destination: url)
                    }
                } label: {
                    Text("Notifications are turned off for Cellar in System Settings.")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Shown when an operation finishes while Cellar is in the background.")
        }
        .task { await refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await refreshStatus() }
        }
    }

    private func refreshStatus() async {
        status = await ActivityNotificationService.shared.authorizationStatus()
    }
}

// MARK: - Maintenance

private struct MaintenanceTab: View {
    @Environment(MaintenanceStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section {
                Toggle("Clean Up Automatically", isOn: $store.schedule.autoCleanup)
                Picker("Frequency", selection: $store.schedule.cleanupFrequency) {
                    frequencyOptions
                }
                .disabled(!store.schedule.autoCleanup)
            } header: {
                Text("Cleanup")
            } footer: {
                Text("Removes old package versions and cached downloads.")
            }

            Section {
                Toggle("Run Health Check Automatically", isOn: $store.schedule.autoHealthCheck)
                Picker("Frequency", selection: $store.schedule.healthCheckFrequency) {
                    frequencyOptions
                }
                .disabled(!store.schedule.autoHealthCheck)
            } header: {
                Text("Health Check")
            } footer: {
                Text("Runs `brew doctor`. Scheduled tasks run only while Cellar is open; Cellar checks once an hour whether one is due.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: [store.schedule.autoCleanup, store.schedule.autoHealthCheck]) { self.store.saveSettings() }
        .onChange(of: [store.schedule.cleanupFrequency, store.schedule.healthCheckFrequency]) { self.store.saveSettings() }
    }

    private var frequencyOptions: some View {
        ForEach(MaintenanceFrequency.allCases, id: \.self) { frequency in
            Text(frequency.title).tag(frequency)
        }
    }
}

// MARK: - Extensions

private struct ExtensionsTab: View {
    var body: some View {
        Form {
            Section {
                CLIToolRow()
            } header: {
                Text("Command Line Tool")
            } footer: {
                Text("Installs the `cellar` command at /usr/local/bin so you can manage Homebrew from the terminal.")
            }

            Section {
                FinderExtensionRow()
                FinderMonitoredPathsRow()
            } header: {
                Text("Finder Extension")
            } footer: {
                Text("Badges folders containing a Brewfile and adds service controls to Finder\u{2019}s context menu. Adding Desktop or Documents will trigger a system permission prompt.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutTab: View {
    private static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        Form {
            Section {
                VStack(spacing: Spacing.sectionContent) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.extraLarge))
                        .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)

                    Text("Cellar")
                        .font(.title2.bold())

                    Text("Version \(Self.version) (\(Self.buildNumber))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sectionContent)
            }

            UpdateSection()

            Section {
                BrewInfoRow()
            } header: {
                Text("Homebrew")
            }

            Section {
                HStack(spacing: Spacing.cardPadding) {
                    if let brewURL = URL(string: "https://brew.sh") {
                        Link("Homebrew Website", destination: brewURL)
                    }
                    if let repoURL = URL(string: "https://github.com/tuhage/Cellar") {
                        Link("GitHub", destination: repoURL)
                    }
                }
            } header: {
                Text("Links")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Update Section

private struct UpdateSection: View {
    @Environment(UpdateStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Section {
            Toggle("Check for Cellar Updates Automatically", isOn: $store.automaticallyChecksForUpdates)

            Toggle("Download and Install Automatically", isOn: $store.automaticallyDownloadsUpdates)
                .disabled(!store.automaticallyChecksForUpdates)

            if let lastChecked = store.lastChecked {
                LabeledContent("Last Checked") {
                    Text(lastChecked, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                store.checkForUpdates()
            } label: {
                Label("Check for Cellar Updates\u{2026}", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: {
            Text("Updates")
        } footer: {
            Text("Updates are downloaded from signed GitHub Releases and verified before installation. Automatic updates are installed when Cellar is idle or the app quits.")
        }
        .onAppear { store.refreshPreferences() }
    }
}

// MARK: - Brew Info

private struct BrewInfoRow: View {
    @State private var brewVersion = "Loading\u{2026}"
    @State private var brewPrefix: String?

    var body: some View {
        LabeledContent("Version") {
            Text(brewVersion)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .task { await loadBrewInfo() }

        if let brewPrefix {
            LabeledContent("Prefix") {
                Text(brewPrefix)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func loadBrewInfo() async {
        async let version = try? BrewService.shared.version()
        async let prefix = try? BrewService.shared.path(of: .prefix)
        brewVersion = await version ?? "Not found"
        brewPrefix = await prefix
    }
}

// MARK: - CLI Tool Row

private struct CLIToolRow: View {
    @State private var status: CLIInstallService.CLIStatus = .notInstalled
    @State private var errorMessage: String?

    private let service = CLIInstallService()

    var body: some View {
        Group {
            switch status {
            case .notBundled:
                LabeledContent("Status") {
                    Label("Binary not found", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                }

            case .notInstalled:
                LabeledContent("Status") {
                    Text("Not installed")
                        .foregroundStyle(.secondary)
                }
                Button("Install") {
                    install()
                }

            case .installed(let path):
                LabeledContent("Status") {
                    Label("Installed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                LabeledContent("Path") {
                    Text(path)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                Button("Uninstall", role: .destructive) {
                    uninstall()
                }

            case .conflict(let path):
                LabeledContent("Status") {
                    Label("Conflict", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                LabeledContent("Existing file") {
                    Text(path)
                        .fontDesign(.monospaced)
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                }
                Button("Replace and Install") {
                    install()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task { refreshStatus() }
    }

    private func install() {
        errorMessage = nil
        do {
            try service.install()
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshStatus()
    }

    private func uninstall() {
        errorMessage = nil
        do {
            try service.uninstall()
        } catch {
            errorMessage = error.localizedDescription
        }
        refreshStatus()
    }

    private func refreshStatus() {
        status = service.status()
    }
}

// MARK: - Finder Extension Row

private struct FinderExtensionRow: View {
    @State private var isEnabled = FIFinderSyncController.isExtensionEnabled

    var body: some View {
        LabeledContent("Status") {
            if isEnabled {
                Label("Enabled", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Text("Disabled")
                    .foregroundStyle(.secondary)
            }
        }

        Button(isEnabled ? "Manage in System Settings\u{2026}" : "Enable in System Settings\u{2026}") {
            FIFinderSyncController.showExtensionManagementInterface()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isEnabled = FIFinderSyncController.isExtensionEnabled
        }
    }
}

// MARK: - Finder Monitored Paths

/// Folders the Finder extension watches for Brewfiles, edited like any Mac
/// list: select a row, then + or −.
private struct FinderMonitoredPathsRow: View {
    @State private var paths: [String] = AppGroupStorage.finderSyncPaths
    @State private var selection: String?
    @State private var isChoosingFolder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(paths, id: \.self, selection: $selection) { path in
                Label(path.abbreviatingWithTildeInPath, systemImage: "folder")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(minHeight: 96)
            .listStyle(.bordered(alternatesRowBackgrounds: true))

            HStack(spacing: 0) {
                Button("Add Folder", systemImage: "plus") { isChoosingFolder = true }
                Button("Remove Folder", systemImage: "minus") {
                    if let selection { remove(selection) }
                }
                .disabled(selection == nil)
                Spacer()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .padding(.top, Spacing.compact)
        }
        .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder], onCompletion: add)
        .fileDialogMessage("Choose a folder to monitor for Brewfiles")
    }

    private func remove(_ path: String) {
        paths.removeAll { $0 == path }
        selection = nil
        AppGroupStorage.finderSyncPaths = paths
    }

    private func add(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let path = url.path(percentEncoded: false)
        guard !paths.contains(path) else { return }
        paths.append(path)
        AppGroupStorage.finderSyncPaths = paths
    }
}

#Preview {
    SettingsView()
        .environment(AppStores())
}
