import SwiftUI
import CellarCore

struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval = 5.0
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("confirmBeforeUninstall") private var confirmBeforeUninstall = true
    @AppStorage("showNotifications") private var showNotifications = true

    var body: some View {
        Form {
            Section("General") {
                Picker("Service Refresh Interval", selection: $refreshInterval) {
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }

                Toggle("Show Menu Bar Icon", isOn: $showMenuBarExtra)
            }

            Section("Packages") {
                Toggle("Confirm Before Uninstall", isOn: $confirmBeforeUninstall)
            }

            Section("Notifications") {
                Toggle("Enable Notifications", isOn: $showNotifications)
            }

            Section("About") {
                HStack(spacing: Spacing.sectionContent) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.card))

                    VStack(alignment: .leading, spacing: Spacing.textPair) {
                        Text("Cellar")
                            .font(.headline)
                        Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, Spacing.compact)

                Link(destination: URL(string: "https://brew.sh")!) {
                    Label("Homebrew Website", systemImage: "globe")
                }
            }

            Section("Homebrew") {
                BrewInfoRow()
            }
        }
        .formStyle(.grouped)
    }
}

private struct BrewInfoRow: View {
    @State private var brewVersion = "Loading\u{2026}"
    @State private var brewPrefix = ""

    var body: some View {
        Group {
            LabeledContent("Brew Version") {
                Text(brewVersion)
                    .fontDesign(.monospaced)
            }
            if !brewPrefix.isEmpty {
                LabeledContent("Prefix", value: brewPrefix)
            }
        }
        .task { await loadBrewInfo() }
    }

    private func loadBrewInfo() async {
        let process = BrewProcess()
        do {
            let versionOutput = try await process.run(["--version"])
            let version = versionOutput.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !version.isEmpty {
                brewVersion = version.components(separatedBy: "\n").first ?? version
            } else {
                brewVersion = "Unknown"
            }
        } catch {
            brewVersion = "Not found"
        }
        do {
            let prefixOutput = try await process.run(["--prefix"])
            let prefix = prefixOutput.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty {
                brewPrefix = prefix
            }
        } catch {
            // Prefix is optional
        }
    }
}

#Preview {
    SettingsView()
}
