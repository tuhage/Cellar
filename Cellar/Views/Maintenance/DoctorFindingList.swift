import AppKit
import SwiftUI
import CellarCore

/// `brew doctor`'s result as rows: a success state, or one expandable row per
/// warning with its explanation and copyable commands. Place it in a `Form`
/// section or a `DisclosureGroup`.
struct DoctorFindingList: View {
    let report: DoctorReport

    var body: some View {
        if report.findings.isEmpty {
            if report.isReadyToBrew {
                Label {
                    Text("Your system is ready to brew")
                    Text("brew doctor found no problems.")
                } icon: {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Text("brew doctor finished without warnings.")
                    .foregroundStyle(.secondary)
            }
        } else {
            ForEach(report.findings) { finding in
                DoctorFindingRow(finding: finding)
            }
        }
    }
}

// MARK: - Finding

private struct DoctorFindingRow: View {
    let finding: DoctorReport.Finding

    var body: some View {
        DisclosureGroup {
            ForEach(Array(finding.blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    Text(text)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                case .command(let command):
                    CommandRow(command: command)
                }
            }
        } label: {
            Label {
                Text(finding.title)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Warning")
            }
        }
    }
}

// MARK: - Command

/// A suggested shell command with a Copy button; Cellar never runs these.
private struct CommandRow: View {
    let command: String

    @State private var isCopied = false

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
            Text(command)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
                isCopied = true
            } label: {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .help(isCopied ? "Copied" : "Copy Command")
            .accessibilityLabel(isCopied ? "Copied" : "Copy Command")
        }
        .padding(Spacing.item)
        .cardStyle(cornerRadius: CornerRadius.small)
        .task(id: isCopied) {
            guard isCopied else { return }
            try? await Task.sleep(for: .seconds(2))
            isCopied = false
        }
    }
}

// MARK: - Preview

#Preview("Warnings") {
    Form {
        Section("Health") {
            DoctorFindingList(report: .preview)
        }
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 420)
}

#Preview("Ready to Brew") {
    Form {
        Section("Health") {
            DoctorFindingList(report: DoctorReport(output: "Your system is ready to brew."))
        }
    }
    .formStyle(.grouped)
    .frame(width: 560, height: 200)
}
