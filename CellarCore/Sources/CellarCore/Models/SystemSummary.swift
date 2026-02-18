import Foundation

// MARK: - SystemSummary

/// Aggregates system-wide Homebrew statistics at a point in time.
///
/// `Codable` so the last-known summary can be cached to disk and shown
/// instantly on next launch (stale-while-revalidate). The live data
/// replaces the cached version once brew commands complete.
public struct SystemSummary: Codable, Sendable {

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

    /// Whether any installed packages have available updates.
    public var hasOutdatedPackages: Bool { updatesAvailable > 0 }

    /// Whether any services are in an error state.
    public var hasFailedServices: Bool { services.contains(where: \.isError) }

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
            .compactMap { formula in formula.installTime.map { (formula, $0) } }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map(\.0)

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
