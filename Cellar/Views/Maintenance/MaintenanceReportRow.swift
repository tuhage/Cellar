import SwiftUI
import CellarCore

/// A past maintenance run. Expands to brew's output — for a health check,
/// its findings with copyable commands.
struct MaintenanceReportRow: View {
    let report: MaintenanceReport

    var body: some View {
        if let details = report.details {
            DisclosureGroup {
                if report.type == .healthCheck {
                    DoctorFindingList(report: DoctorReport(output: details))
                } else {
                    Text(details)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } label: {
                summary
            }
        } else {
            summary
        }
    }

    private var summary: some View {
        LabeledContent {
            Text(report.date.formatted(.relative(presentation: .named)))
                .help(report.date.formatted(date: .abbreviated, time: .shortened))
        } label: {
            Label {
                Text(report.type.title)
                Text(report.summary)
            } icon: {
                Image(systemName: report.type.icon)
                    .foregroundStyle(report.type.color)
            }
        }
    }
}

private extension MaintenanceReportType {
    var color: Color {
        switch self {
        case .cleanup: .orange
        case .autoremove: .blue
        case .healthCheck: .green
        }
    }
}

// MARK: - Preview

#Preview {
    Form {
        Section("Reports") {
            MaintenanceReportRow(report: .preview)
            MaintenanceReportRow(report: MaintenanceReport(
                type: .healthCheck,
                summary: "Your system is ready to brew. No issues found.",
                details: "Your system is ready to brew."
            ))
        }
    }
    .formStyle(.grouped)
    .frame(width: 600, height: 400)
}
