import Foundation

/// A lightweight snapshot of app state written by the main app and read by the widget.
///
/// Stored in the shared App Group container as `widget-snapshot.json`.
public struct WidgetSnapshot: Codable, Sendable {
    public let totalFormulae: Int
    public let totalCasks: Int
    public let runningServices: Int
    public let totalServices: Int
    public let outdatedCount: Int
    public let runningServiceNames: [String]
    public let stoppedServiceNames: [String]
    public let outdatedPackageNames: [String]
    public let lastUpdated: Date

    public init(
        totalFormulae: Int,
        totalCasks: Int,
        runningServices: Int,
        totalServices: Int,
        outdatedCount: Int,
        runningServiceNames: [String],
        stoppedServiceNames: [String] = [],
        outdatedPackageNames: [String],
        lastUpdated: Date = .now
    ) {
        self.totalFormulae = totalFormulae
        self.totalCasks = totalCasks
        self.runningServices = runningServices
        self.totalServices = totalServices
        self.outdatedCount = outdatedCount
        self.runningServiceNames = runningServiceNames
        self.stoppedServiceNames = stoppedServiceNames
        self.outdatedPackageNames = outdatedPackageNames
        self.lastUpdated = lastUpdated
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalFormulae = try container.decode(Int.self, forKey: .totalFormulae)
        totalCasks = try container.decode(Int.self, forKey: .totalCasks)
        runningServices = try container.decode(Int.self, forKey: .runningServices)
        totalServices = try container.decode(Int.self, forKey: .totalServices)
        outdatedCount = try container.decode(Int.self, forKey: .outdatedCount)
        runningServiceNames = try container.decode([String].self, forKey: .runningServiceNames)
        stoppedServiceNames = try container.decodeIfPresent([String].self, forKey: .stoppedServiceNames) ?? []
        outdatedPackageNames = try container.decode([String].self, forKey: .outdatedPackageNames)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

    // MARK: - Persistence

    public static let fileName = "widget-snapshot.json"

    /// Writes this snapshot to the shared App Group container.
    public func save() {
        AppGroupStorage.save(self, to: Self.fileName)
    }

    /// Reads the most recent snapshot from the shared App Group container.
    public static func load() -> WidgetSnapshot? {
        AppGroupStorage.load(WidgetSnapshot.self, from: fileName)
    }

    /// Creates a snapshot from a `SystemSummary` and service list.
    public static func from(summary: SystemSummary, services: [BrewServiceItem]) -> WidgetSnapshot {
        WidgetSnapshot(
            totalFormulae: summary.totalFormulae,
            totalCasks: summary.totalCasks,
            runningServices: summary.runningServices,
            totalServices: summary.totalServices,
            outdatedCount: summary.updatesAvailable,
            runningServiceNames: services.filter(\.isRunning).map(\.name),
            stoppedServiceNames: services.filter { !$0.isRunning }.map(\.name),
            outdatedPackageNames: summary.outdatedFormulae.map(\.name) + summary.outdatedCasks.map(\.token)
        )
    }

    // MARK: - Preview

    public static var preview: WidgetSnapshot {
        WidgetSnapshot(
            totalFormulae: 142,
            totalCasks: 38,
            runningServices: 4,
            totalServices: 7,
            outdatedCount: 5,
            runningServiceNames: ["postgresql@16", "redis", "nginx", "dnsmasq"],
            stoppedServiceNames: ["mysql", "memcached", "rabbitmq"],
            outdatedPackageNames: ["openssl@3", "node", "python@3.12", "git", "wget"]
        )
    }
}
