import SwiftUI
import UniformTypeIdentifiers
import CellarCore

extension Brewfile {
    var systemImage: String {
        kind == .mac ? "desktopcomputer" : "folder"
    }

    func revealInFinder() {
        let url = exists ? url : folderURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the file in the default plain-text editor — a Brewfile has no
    /// extension, so asking for the file's own default app would fail.
    func openInExternalEditor() {
        let editor = NSWorkspace.shared.urlForApplication(toOpen: .plainText)
            ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit")
        guard let editor else { return }
        NSWorkspace.shared.open([url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
    }
}

extension BrewfileContent.Entry.Kind {
    /// Section title for entries of this kind.
    var title: String {
        switch self {
        case .tap: "Taps"
        case .brew: "Formulae"
        case .cask: "Casks"
        case .mas: "Mac App Store"
        case .vscode: "VS Code Extensions"
        case .go: "Go Packages"
        case .cargo: "Cargo Packages"
        case .whalebrew: "Whalebrew Images"
        case .other: "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .tap: "spigot"
        case .brew: "terminal"
        case .cask: "macwindow"
        case .mas: "bag"
        case .vscode: "chevron.left.forwardslash.chevron.right"
        case .go, .cargo, .whalebrew, .other: "shippingbox"
        }
    }
}

extension BrewfileStore.PackageStatus {
    var label: String {
        switch self {
        case .installed: "Installed"
        case .missing: "Missing"
        case .outdated: "Outdated"
        }
    }

    var color: Color {
        switch self {
        case .installed: .green
        case .missing: .orange
        case .outdated: .blue
        }
    }

    var systemImage: String {
        switch self {
        case .installed: "checkmark.circle"
        case .missing: "exclamationmark.triangle"
        case .outdated: "arrow.up.circle"
        }
    }
}

extension ProjectServiceState {
    var label: String {
        switch self {
        case .noServices: "No services"
        case .running: "Running"
        case .partial(let running, let total): "\(running) of \(total) running"
        case .stopped: "Stopped"
        }
    }

    var color: Color {
        switch self {
        case .running: .green
        case .partial: .orange
        case .stopped, .noServices: .secondary
        }
    }
}

/// A status dot with its label, so state never depends on color alone.
struct StatusDotLabel: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.related) {
            Circle()
                .fill(color)
                .frame(width: IconSize.statusDot, height: IconSize.statusDot)
                .accessibilityHidden(true)
            Text(text)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.item) {
        StatusDotLabel(text: ProjectServiceState.running.label, color: ProjectServiceState.running.color)
        StatusDotLabel(
            text: ProjectServiceState.partial(running: 1, total: 2).label,
            color: ProjectServiceState.partial(running: 1, total: 2).color
        )
        ForEach([BrewfileStore.PackageStatus.installed, .missing, .outdated], id: \.self) { status in
            StatusBadge(text: status.label, color: status.color, icon: status.systemImage)
        }
    }
    .padding()
}
