import SwiftUI
import CellarCore

/// Shown until Homebrew is found: installs it through Terminal, notices when
/// the install finishes, and lets users point to a brew in a custom location.
struct OnboardingView: View {
    let onBrewDetected: () -> Void

    @State private var isWaitingForInstall = false
    @State private var errorMessage: String?

    private static let installCommand =
        "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    private static let detectionInterval: Duration = .seconds(3)

    var body: some View {
        VStack(spacing: Spacing.section) {
            header
            commandBox
            actions
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(AnimationToken.smooth, value: isWaitingForInstall)
        .animation(AnimationToken.smooth, value: errorMessage)
        .task(id: isWaitingForInstall) {
            await detectInstall()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sectionContent) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.item) {
                Text("Welcome to Cellar")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Cellar manages packages, apps and services with Homebrew. Install Homebrew to get started.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text("The installer runs in Terminal, asks for your password, may install the Xcode Command Line Tools, and takes a few minutes.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Command Box

    private var commandBox: some View {
        HStack {
            Text(Self.installCommand)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .lineLimit(2)

            Spacer()

            CopyButton(text: Self.installCommand)
                .buttonStyle(.bordered)
        }
        .padding(Spacing.sectionContent)
        .cardStyle(cornerRadius: CornerRadius.card)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Spacing.sectionContent) {
            if isWaitingForInstall {
                Label {
                    Text("Waiting for Homebrew\u{2026} Cellar continues as soon as the install finishes.")
                } icon: {
                    ProgressView()
                        .controlSize(.small)
                }
                .font(.callout)
            } else {
                Button(action: openInstallerInTerminal) {
                    Label("Install in Terminal", systemImage: "terminal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            HStack(spacing: Spacing.sectionContent) {
                Button("Check Again", systemImage: "arrow.clockwise", action: recheck)
                Button("Locate brew\u{2026}", systemImage: "folder", action: locateBrew)
                    .help("Choose a brew executable installed outside /opt/homebrew or /usr/local")
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .transition(.opacity)
            }

            if let url = URL(string: "https://brew.sh") {
                Link(destination: url) {
                    Label("Learn more at brew.sh", systemImage: "safari")
                        .font(.callout)
                }
            }
        }
    }

    // MARK: - Private

    private func recheck() {
        if BrewProcess.isInstalled {
            onBrewDetected()
        } else {
            errorMessage = "Homebrew wasn’t found. Install it, or locate brew if it’s somewhere else."
        }
    }

    /// Polls while the installer runs in Terminal.
    private func detectInstall() async {
        while isWaitingForInstall, !Task.isCancelled {
            if BrewProcess.isInstalled {
                onBrewDetected()
                return
            }
            try? await Task.sleep(for: Self.detectionInterval)
        }
    }

    private func openInstallerInTerminal() {
        errorMessage = nil
        do {
            try TerminalLauncher.run(Self.installCommand, title: "Install Homebrew")
            isWaitingForInstall = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func locateBrew() {
        let panel = NSOpenPanel()
        panel.title = "Locate brew"
        panel.message = "Choose the brew executable, usually in the bin folder of your Homebrew prefix."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.treatsFilePackagesAsDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard url.lastPathComponent == "brew", FileManager.default.isExecutableFile(atPath: url.path) else {
            errorMessage = "That isn’t a brew executable."
            return
        }
        BrewProcess.customBrewPath = url.path
        recheck()
    }
}

#Preview("Onboarding") {
    OnboardingView(onBrewDetected: {})
        .frame(width: 800, height: 700)
}
