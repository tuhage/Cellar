import SwiftUI
import CellarCore

struct OnboardingView: View {
    var onBrewDetected: () -> Void

    @State private var copied = false
    @State private var showNotFoundError = false

    private static let installCommand =
        "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    var body: some View {
        VStack(spacing: Spacing.section) {
            header
            commandBox
            actions
        }
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: Spacing.sectionContent) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            VStack(spacing: Spacing.item) {
                Text("Welcome to Cellar")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Cellar requires Homebrew to manage your packages, casks, and services. Install Homebrew to get started.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Command Box

    private var commandBox: some View {
        GroupBox {
            HStack {
                Text(Self.installCommand)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .lineLimit(2)

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Self.installCommand, forType: .string)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.bordered)
            }
            .padding(Spacing.compact)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Spacing.sectionContent) {
            Button {
                openTerminalWithInstallCommand()
            } label: {
                Label("Install in Terminal", systemImage: "terminal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                if BrewProcess.isInstalled {
                    onBrewDetected()
                } else {
                    showNotFoundError = true
                }
            } label: {
                Label("Check Again", systemImage: "arrow.clockwise")
            }
            .controlSize(.large)

            if showNotFoundError {
                Label("Homebrew was not found. Please install it and try again.", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            Link(destination: URL(string: "https://brew.sh")!) {
                Label("Learn more at brew.sh", systemImage: "safari")
                    .font(.callout)
            }
        }
    }

    // MARK: - Private

    private func openTerminalWithInstallCommand() {
        let script = """
        tell application "Terminal"
            activate
            do script "\(Self.installCommand)"
        end tell
        """
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(onBrewDetected: {})
}
