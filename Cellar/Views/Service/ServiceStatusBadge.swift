import SwiftUI
import CellarCore

/// A service's status as a colored dot and label; the tooltip explains the
/// status and the exit code. Shows a spinner while an action runs.
struct ServiceStatusBadge: View {
    let service: BrewServiceItem
    var isBusy = false

    var body: some View {
        StatusDotLabel(text: service.status.label, color: service.status.color, isBusy: isBusy)
            .font(.callout)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(service.status.label)")
            .accessibilityValue(isBusy ? "Busy" : "")
            .help(service.statusHelp)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.item) {
        ForEach(ServiceStatus.allCases, id: \.self) { status in
            ServiceStatusBadge(service: BrewServiceItem(
                name: "redis", status: status, user: nil, file: nil,
                exitCode: status == .error ? 78 : nil, pid: nil, registered: nil
            ))
        }
        ServiceStatusBadge(service: .preview, isBusy: true)
    }
    .padding()
}
