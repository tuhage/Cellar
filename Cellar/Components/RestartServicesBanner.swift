import SwiftUI
import CellarCore

/// Offers to restart services that were upgraded while running and so still
/// run the previous version. Shows nothing when there are none.
struct RestartServicesBanner: View {
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(PackageStore.self) private var packageStore

    var body: some View {
        let services = serviceStore.servicesNeedingRestart(formulae: packageStore.formulae)
        if !services.isEmpty {
            NoticeBanner(
                tint: .blue,
                systemImage: "arrow.clockwise.circle.fill",
                title: Self.title(for: services),
                message: Self.message(for: services)
            ) {
                if services.contains(where: serviceStore.isBusy) {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Button(services.count == 1 ? "Restart" : "Restart All") {
                        Task { await serviceStore.restart(services) }
                    }
                }
            }
        }
    }

    private static func title(for services: [BrewServiceItem]) -> String {
        if services.count == 1, let service = services.first {
            return "\(service.name) is still running the previous version"
        }
        let names = services.map(\.name).formatted(.list(type: .and))
        return "\(names) are still running previous versions"
    }

    private static func message(for services: [BrewServiceItem]) -> String {
        let base = "Upgraded while running. Restart to use the new version."
        return services.contains(where: \.requiresRoot)
            ? base + " You’ll be asked for your password."
            : base
    }
}

#Preview {
    RestartServicesBanner()
        .environment(AppStores())
        .frame(width: 600)
}
