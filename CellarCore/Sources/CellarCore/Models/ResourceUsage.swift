import Foundation

// MARK: - ResourceUsage

/// CPU and memory used by a running service, including the worker
/// processes it spawned.
public struct ResourceUsage: Identifiable, Hashable, Sendable {

    // MARK: Properties

    /// One per service, so a table row keeps its identity across samples.
    public var id: String { serviceName }
    public let serviceName: String
    public let pid: Int
    public let processCount: Int
    /// Share of one CPU core: 100 is a full core, so a multi-threaded
    /// service can exceed 100.
    public let cpuPercent: Double
    public let memoryBytes: Int64
    /// Total CPU time of the process tree, kept to measure the next sample.
    public let cpuTime: TimeInterval
    public let timestamp: Date

    public init(
        serviceName: String,
        pid: Int,
        processCount: Int = 1,
        cpuPercent: Double,
        memoryBytes: Int64,
        cpuTime: TimeInterval = 0,
        timestamp: Date = .now
    ) {
        self.serviceName = serviceName
        self.pid = pid
        self.processCount = processCount
        self.cpuPercent = cpuPercent
        self.memoryBytes = memoryBytes
        self.cpuTime = cpuTime
        self.timestamp = timestamp
    }

    // MARK: Measuring

    /// Measures the process tree rooted at `pid`. CPU is the CPU time used
    /// since `previous` over the time between the samples; `ps`'s own
    /// figure, an average that decays over a minute, only stands in for the
    /// first sample of a process.
    public static func measure(
        serviceName: String,
        pid: Int,
        in table: ProcessTable,
        previous: ResourceUsage?
    ) -> ResourceUsage? {
        guard let tree = table.treeUsage(of: pid) else { return nil }
        var cpuPercent = tree.cpuPercent
        if let previous, previous.pid == pid {
            let elapsed = table.capturedAt.timeIntervalSince(previous.timestamp)
            if elapsed > 0 {
                // A worker that exited takes its CPU time with it; never go negative.
                cpuPercent = max(0, tree.cpuTime - previous.cpuTime) / elapsed * 100
            }
        }
        return ResourceUsage(
            serviceName: serviceName,
            pid: pid,
            processCount: tree.processCount,
            cpuPercent: cpuPercent,
            memoryBytes: tree.residentBytes,
            cpuTime: tree.cpuTime,
            timestamp: table.capturedAt
        )
    }

    // MARK: Preview

    public static var preview: ResourceUsage {
        ResourceUsage(
            serviceName: "postgresql@16",
            pid: 12345,
            processCount: 7,
            cpuPercent: 2.4,
            memoryBytes: 61_132_800
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
