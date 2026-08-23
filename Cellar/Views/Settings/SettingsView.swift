import SwiftUI
import FinderSync
import CellarCore

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }

            ExtensionsTab()
                .tabItem { Label("Extensions", systemImage: "puzzlepiece.extension") }

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 540, height: 520)
    }
}

// MARK: - General

private struct GeneralTab: View {
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("confirmBeforeUninstall") private var confirmBeforeUninstall = true
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        Form {
            Section {
                Picker("Service Refresh Interval", selection: $refreshInterval) {
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarExtra)
            }

            Section {
                Toggle("Confirm Before Uninstall", isOn: $confirmBeforeUninstall)
            } header: {
                Text("Packages")
            }

            Section {
                Toggle("Enable Notifications", isOn: $showNotifications)
            } header: {
                Text("Notifications")
            }
        }
        .formStyle(.grouped)
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

                    Text("Build \(Self.buildNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
            LabeledContent("Current Version") {
                Text("\(store.currentVersion) (\(store.currentBuild))")
                    .foregroundStyle(.secondary)
            }

            Toggle("Check for Updates Automatically", isOn: $store.automaticallyChecksForUpdates)

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
                Label("Check for Updates\u{2026}", systemImage: "arrow.triangle.2.circlepath")
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
    @State private var brewPrefix = ""

    var body: some View {
        LabeledContent("Version") {
            Text(brewVersion)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
        }
        .task { await loadBrewInfo() }

        if !brewPrefix.isEmpty {
            LabeledContent("Prefix") {
                Text(brewPrefix)
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func loadBrewInfo() async {
        let process = BrewProcess()

        if let output = try? await process.run(["--version"]) {
            let firstLine = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: "\n").first ?? ""
            brewVersion = firstLine.isEmpty ? "Unknown" : firstLine
        } else {
            brewVersion = "Not found"
        }

        if let output = try? await process.run(["--prefix"]) {
            let prefix = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty { brewPrefix = prefix }
        }
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

private struct FinderMonitoredPathsRow: View {
    @State private var paths: [String] = AppGroupStorage.finderSyncPaths

    var body: some View {
        LabeledContent("Monitored Folders") {
            VStack(alignment: .trailing, spacing: Spacing.compact) {
                ForEach(paths, id: \.self) { path in
                    HStack(spacing: Spacing.related) {
                        Text(abbreviate(path))
                            .font(.callout)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Button {
                            remove(path)
                        } label: {
                            Image(systemName: "minus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(width: 20, height: 20)
                                .background(.red.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(abbreviate(path))")
                    }
                }

                Button("Add Folder\u{2026}") {
                    addFolder()
                }
                .font(.callout)
            }
        }
    }

    private func abbreviate(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func remove(_ path: String) {
        paths.removeAll { $0 == path }
        save()
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Folder to Monitor"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let path = url.path

        guard !paths.contains(path) else { return }
        paths.append(path)
        save()
    }

    private func save() {
        AppGroupStorage.finderSyncPaths = paths
    }
}

#Preview {
    SettingsView()
        .environment(UpdateStore(startingUpdater: false))
}
