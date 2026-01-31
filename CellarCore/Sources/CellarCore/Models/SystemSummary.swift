import Foundation

// MARK: - SystemSummary

/// Aggregates system-wide Homebrew statistics at a point in time.
///
/// Not `Codable` — this is computed at runtime from live brew data,
/// never persisted. Used by `DashboardStore` to power the dashboard view.
public struct SystemSummary: Sendable {

    // MARK: Data

    public let totalFormulae: Int
    public let totalCasks: Int
    public let runningServices: Int
    public let totalServices: Int
    public let updatesAvailable: Int
    public let outdatedFormulae: [Formula]
    public let outdatedCasks: [Cask]
    public let services: [BrewServiceItem]
    public let recentlyInstalled: [Formula]
    public let taps: [Tap]

    /// Total packages across both formulae and casks.
    public var totalPackages: Int {
        totalFormulae + totalCasks
    }

    // MARK: Init

    public init(
        totalFormulae: Int,
        totalCasks: Int,
        runningServices: Int,
        totalServices: Int,
        updatesAvailable: Int,
        outdatedFormulae: [Formula],
        outdatedCasks: [Cask],
        services: [BrewServiceItem],
        recentlyInstalled: [Formula],
        taps: [Tap]
    ) {
        self.totalFormulae = totalFormulae
        self.totalCasks = totalCasks
        self.runningServices = runningServices
        self.totalServices = totalServices
        self.updatesAvailable = updatesAvailable
        self.outdatedFormulae = outdatedFormulae
        self.outdatedCasks = outdatedCasks
        self.services = services
        self.recentlyInstalled = recentlyInstalled
        self.taps = taps
    }

    // MARK: Factory Method

    /// Builds a summary from the current state of loaded data.
    public static func current(
        formulae: [Formula],
        casks: [Cask],
        services: [BrewServiceItem],
        taps: [Tap]
    ) -> SystemSummary {
        let outdatedFormulae = formulae.filter(\.outdated)
        let outdatedCasks = casks.filter(\.outdated)

        let recentlyInstalled = formulae
            .filter { $0.installTime != nil }
            .sorted { $0.installTime! > $1.installTime! }
            .prefix(5)

        return SystemSummary(
            totalFormulae: formulae.count,
            totalCasks: casks.count,
            runningServices: services.filter(\.isRunning).count,
            totalServices: services.count,
            updatesAvailable: outdatedFormulae.count + outdatedCasks.count,
            outdatedFormulae: outdatedFormulae,
            outdatedCasks: outdatedCasks,
            services: services,
            recentlyInstalled: Array(recentlyInstalled),
            taps: taps
        )
    }

    // MARK: Preview

    public static var preview: SystemSummary {
        SystemSummary(
            totalFormulae: 142,
            totalCasks: 38,
            runningServices: 4,
            totalServices: 7,
            updatesAvailable: 5,
            outdatedFormulae: [.preview],
            outdatedCasks: [.preview],
            services: [
                .preview,
                BrewServiceItem(name: "redis", status: .stopped, user: nil, file: nil, exitCode: nil, pid: nil, registered: true),
                BrewServiceItem(name: "nginx", status: .error, user: nil, file: nil, exitCode: 1, pid: nil, registered: true),
            ],
            recentlyInstalled: [.preview],
            taps: [.preview]
        )
    }
}
