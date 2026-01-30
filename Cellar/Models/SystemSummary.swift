import Foundation

// MARK: - SystemSummary

/// Aggregates system-wide Homebrew statistics at a point in time.
///
/// Not `Codable` — this is computed at runtime from live brew data,
/// never persisted. Used by `DashboardStore` to power the dashboard view.
struct SystemSummary: Sendable {

    // MARK: Data

    let totalFormulae: Int
    let totalCasks: Int
    let runningServices: Int
    let totalServices: Int
    let updatesAvailable: Int
    let outdatedFormulae: [Formula]
    let outdatedCasks: [Cask]

    /// Total packages across both formulae and casks.
    var totalPackages: Int {
        totalFormulae + totalCasks
    }

    // MARK: Factory Method

    /// Builds a summary from the current state of loaded data.
    static func current(
        formulae: [Formula],
        casks: [Cask],
        services: [BrewServiceItem]
    ) -> SystemSummary {
        let outdatedFormulae = formulae.filter(\.outdated)
        let outdatedCasks = casks.filter(\.outdated)

        return SystemSummary(
            totalFormulae: formulae.count,
            totalCasks: casks.count,
            runningServices: services.filter(\.isRunning).count,
            totalServices: services.count,
            updatesAvailable: outdatedFormulae.count + outdatedCasks.count,
            outdatedFormulae: outdatedFormulae,
            outdatedCasks: outdatedCasks
        )
    }

    // MARK: Preview

    static var preview: SystemSummary {
        SystemSummary(
            totalFormulae: 142,
            totalCasks: 38,
            runningServices: 4,
            totalServices: 7,
            updatesAvailable: 5,
            outdatedFormulae: [.preview],
            outdatedCasks: [.preview]
        )
    }
}
