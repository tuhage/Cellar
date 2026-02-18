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
        .frame(width: 500)
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
        .scrollDisabled(true)
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
        .scrollDisabled(true)
    }
}

// MARK: - About

private struct AboutTab: View {
    private static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: Spacing.section) {
            Spacer()

            VStack(spacing: Spacing.sectionContent) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.extraLarge))
                    .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)

                VStack(spacing: Spacing.compact) {
                    Text("Cellar")
                        .font(.title.bold())

                    Text("Version \(Self.appVersion) (\(Self.buildNumber))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            BrewInfoRow()
                .frame(maxWidth: 300)

            Spacer()

            HStack(spacing: Spacing.cardPadding) {
                if let brewURL = URL(string: "https://brew.sh") {
                    Link(destination: brewURL) {
                        Text("Homebrew Website")
                    }
                }

                if let repoURL = URL(string: "https://github.com/tuhage/Cellar") {
                    Link(destination: repoURL) {
                        Text("GitHub")
                    }
                }
            }
            .font(.caption)
            .padding(.bottom, Spacing.cardPadding)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Brew Info

private struct BrewInfoRow: View {
    @State private var brewVersion = "Loading\u{2026}"
    @State private var brewPrefix = ""

    var body: some View {
        VStack(spacing: Spacing.item) {
            row(label: "Brew", value: brewVersion)
            if !brewPrefix.isEmpty {
                row(label: "Prefix", value: brewPrefix)
            }
        }
        .padding(Spacing.sectionContent)
        .cardStyle(cornerRadius: CornerRadius.card)
        .task { await loadBrewInfo() }
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
        }
        .font(.callout)
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
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
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
}
