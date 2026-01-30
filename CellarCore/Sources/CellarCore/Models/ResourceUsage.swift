import Foundation

// MARK: - ResourceUsage

/// Represents the CPU and memory usage of a running Homebrew service.
///
/// Created by querying `ps` for a given PID. Each snapshot is timestamped
/// so views can display the most recent reading.
public struct ResourceUsage: Identifiable, Sendable {

    // MARK: Properties

    public let id: UUID
    public let serviceName: String
    public let pid: Int
    public let cpuPercent: Double
    public let memoryMB: Double
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        serviceName: String,
        pid: Int,
        cpuPercent: Double,
        memoryMB: Double,
        timestamp: Date = .now
    ) {
        self.id = id
        self.serviceName = serviceName
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.timestamp = timestamp
    }

    // MARK: Preview

    public static var preview: ResourceUsage {
        ResourceUsage(
            serviceName: "postgresql@16",
            pid: 12345,
            cpuPercent: 2.4,
            memoryMB: 58.3
        )
    }
}

// MARK: - DiskUsage

/// Summarises disk space consumed by Homebrew directories.
///
/// Each field holds a human-readable size string (e.g. "2.5 GB")
/// produced by the `du -sh` command.
public struct DiskUsage: Sendable {

    // MARK: Properties

    public let homebrewTotal: String
    public let cellarSize: String
    public let cacheSize: String

    public init(homebrewTotal: String, cellarSize: String, cacheSize: String) {
        self.homebrewTotal = homebrewTotal
        self.cellarSize = cellarSize
        self.cacheSize = cacheSize
    }

    // MARK: Preview

    public static var preview: DiskUsage {
        DiskUsage(
            homebrewTotal: "2.5 GB",
            cellarSize: "1.8 GB",
            cacheSize: "450 MB"
        )
    }
}
