import SwiftUI
import CellarCore

/// Offers to restart services that were upgraded while running and so still
/// run the previous version.
struct RestartServicesBanner: View {
    let services: [BrewServiceItem]
    var isRestarting = false
    let restart: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "arrow.clockwise.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.item)

            if isRestarting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button(services.count == 1 ? "Restart" : "Restart All", action: restart)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .padding(.vertical, Spacing.row)
        .background(.blue.opacity(0.06))
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if services.count == 1, let service = services.first {
            return "\(service.name) is still running the previous version"
        }
        let names = services.map(\.name).formatted(.list(type: .and))
        return "\(names) are still running previous versions"
    }

    private var detail: String {
        let base = "Upgraded while running. Restart to use the new version."
        return services.contains(where: \.requiresRoot)
            ? base + " You'll be asked for your password."
            : base
    }
}

#Preview {
    RestartServicesBanner(
        services: [
            BrewServiceItem(name: "postgresql@17", status: .started, user: "tuhage", file: nil, exitCode: nil, pid: 1828, registered: true),
            BrewServiceItem(name: "tailscale", status: .started, user: "root", file: nil, exitCode: nil, pid: 813, registered: true),
        ]
    ) {}
    .frame(width: 600)
}
