import SwiftUI
import CellarCore

/// Explains a recognized failure and offers its fixes: what went wrong,
/// what to do, and buttons that do it — so a failure isn't a dead end.
struct BrewIssueView: View {
    let issue: BrewIssue

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            Label {
                Text(issue.title)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
            }

            Text(issue.explanation)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(issue.remedies, id: \.self) { remedy in
                RemedyControl(remedy: remedy, errorMessage: $errorMessage)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .font(.caption)
        .padding(Spacing.item)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.yellow.opacity(0.08), in: .rect(cornerRadius: CornerRadius.small))
    }
}

// MARK: - Remedy Control

/// One fix: a button, plus the command itself for Terminal fixes so the
/// user sees what will run and can copy it instead.
private struct RemedyControl: View {
    let remedy: BrewIssue.Remedy
    @Binding var errorMessage: String?

    var body: some View {
        switch remedy {
        case .terminal(let command):
            VStack(alignment: .leading, spacing: Spacing.compact) {
                Text(command)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(Spacing.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: CornerRadius.small))
                HStack(spacing: Spacing.item) {
                    button
                    CopyButton(text: command, title: "Copy Command")
                }
            }
        default:
            button
        }
    }

    private var button: some View {
        Button(remedy.title, systemImage: remedy.symbolName) {
            errorMessage = nil
            do {
                try remedy.perform()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
        .controlSize(.small)
    }
}

// MARK: - Remedy Actions

extension BrewIssue.Remedy {

    var title: String {
        switch self {
        case .softwareUpdate: "Open Software Update"
        case .terminal: "Run in Terminal"
        case .maintenance: "Open Maintenance"
        case .reveal: "Show in Finder"
        }
    }

    var symbolName: String {
        switch self {
        case .softwareUpdate: "gear.badge"
        case .terminal: "terminal"
        case .maintenance: SidebarItem.maintenance.icon
        case .reveal: "folder"
        }
    }

    private static let softwareUpdateURL = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension")!

    func perform() throws {
        switch self {
        case .softwareUpdate:
            NSWorkspace.shared.open(Self.softwareUpdateURL)
        case .terminal(let command):
            try TerminalLauncher.run(command, title: "Cellar Fix")
        case .maintenance:
            Navigator.show(.maintenance)
            NSApplication.shared.cellarMainWindow?.makeKeyAndOrderFront(nil)
        case .reveal(let path):
            NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.item) {
        BrewIssueView(issue: .outdatedCommandLineTools)
        BrewIssueView(issue: .diskFull)
        BrewIssueView(issue: .offline)
    }
    .padding()
    .frame(width: 380)
}
