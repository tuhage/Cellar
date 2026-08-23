import SwiftUI
import CellarCore

struct OnboardingView: View {
    let onBrewDetected: () -> Void

    @State private var isCopied = false
    @State private var showNotFoundError = false

    private static let installCommand =
        "/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""

    var body: some View {
        VStack(spacing: Spacing.section) {
            header
            setupSteps
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
                .shadow(color: Shadow.elevatedColor, radius: Shadow.elevatedBlur, y: Shadow.elevatedY)

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

    private var setupSteps: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            setupStep(number: 1, title: "Install", subtitle: "Open Terminal")
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, Spacing.item)
            setupStep(number: 2, title: "Complete", subtitle: "Follow Homebrew")
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, Spacing.item)
            setupStep(number: 3, title: "Recheck", subtitle: "Return to Cellar")
        }
        .padding(Spacing.sectionContent)
        .cardStyle(cornerRadius: CornerRadius.card)
    }

    private func setupStep(number: Int, title: String, subtitle: String) -> some View {
        HStack(spacing: Spacing.item) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
                .frame(width: 24, height: 24)
                .background(.tint.opacity(Opacity.iconBackground), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Command Box

    private var commandBox: some View {
        HStack {
            Text(Self.installCommand)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)

            Spacer()

            Button(action: copyInstallCommand) {
                Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.bordered)
        }
        .padding(Spacing.sectionContent)
        .background(.primary.opacity(0.03))
        .cardStyle(cornerRadius: CornerRadius.card)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: Spacing.sectionContent) {
            Button(action: openTerminalWithInstallCommand) {
                Label("Install in Terminal", systemImage: "terminal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .shadow(color: Shadow.cardColor, radius: Shadow.cardBlur, y: Shadow.cardY)

            Button(action: recheckBrew) {
                Label("Check Again", systemImage: "arrow.clockwise")
            }
            .controlSize(.large)

            if showNotFoundError {
                Label("Homebrew was not found. Please install it and try again.", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(AnimationToken.snap, value: showNotFoundError)
            }

            Link(destination: URL(string: "https://brew.sh")!) {
                Label("Learn more at brew.sh", systemImage: "safari")
                    .font(.callout)
            }
        }
    }

    // MARK: - Private

    private func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(Self.installCommand, forType: .string)
        isCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }

    private func recheckBrew() {
        if BrewProcess.isInstalled {
            onBrewDetected()
        } else {
            showNotFoundError = true
        }
    }

    private func openTerminalWithInstallCommand() {
        let script = """
        tell application "Terminal"
            activate
            do script "\(Self.installCommand)"
        end tell
        """
        guard let appleScript = NSAppleScript(source: script) else { return }
        var error: NSDictionary?
        appleScript.executeAndReturnError(&error)
    }
}

#Preview("Onboarding") {
    OnboardingView(onBrewDetected: {})
}
