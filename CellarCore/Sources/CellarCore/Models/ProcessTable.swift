import Foundation

/// A snapshot of every process on the Mac, from one `ps` call, so a
/// service's usage can include the worker processes it spawned.
public struct ProcessTable: Sendable {

    public struct Entry: Equatable, Sendable {
        public let pid: Int
        public let parentPID: Int
        /// `ps`'s decaying average; only used until a second snapshot gives a real rate.
        public let cpuPercent: Double
        public let residentBytes: Int64
        /// Total CPU time used since the process started.
        public let cpuTime: TimeInterval
    }

    /// Resources used by a process and all its descendants.
    public struct TreeUsage: Equatable, Sendable {
        public let processCount: Int
        public let cpuPercent: Double
        public let residentBytes: Int64
        public let cpuTime: TimeInterval
    }

    public let capturedAt: Date
    private let entries: [Int: Entry]
    private let childrenByParent: [Int: [Int]]

    init(entries: [Entry], capturedAt: Date) {
        self.capturedAt = capturedAt
        self.entries = Dictionary(entries.map { ($0.pid, $0) }, uniquingKeysWith: { first, _ in first })
        self.childrenByParent = Dictionary(grouping: entries, by: \.parentPID).mapValues { $0.map(\.pid) }
    }

    /// Reads the process table now, or `nil` if `ps` failed.
    public static func current() async -> ProcessTable? {
        let output = await SystemCommand.output("/bin/ps", ["-A", "-o", "pid=,ppid=,%cpu=,rss=,time="])
        return output.map { parse($0, capturedAt: Date()) }
    }

    /// Sums `pid` and its descendants, or `nil` if `pid` isn't running.
    public func treeUsage(of pid: Int) -> TreeUsage? {
        guard entries[pid] != nil else { return nil }
        var pending = [pid]
        var tree: [Entry] = []
        while let next = pending.popLast() {
            guard let entry = entries[next] else { continue }
            tree.append(entry)
            pending += childrenByParent[next, default: []].filter { $0 != next }
        }
        return TreeUsage(
            processCount: tree.count,
            cpuPercent: tree.reduce(0) { $0 + $1.cpuPercent },
            residentBytes: tree.reduce(0) { $0 + $1.residentBytes },
            cpuTime: tree.reduce(0) { $0 + $1.cpuTime }
        )
    }

    // MARK: Parsing

    /// Parses rows of `pid ppid %cpu rss(KiB) time`.
    static func parse(_ output: String, capturedAt: Date) -> ProcessTable {
        let entries = output.split(whereSeparator: \.isNewline).compactMap { line -> Entry? in
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 5,
                  let pid = Int(fields[0]),
                  let parentPID = Int(fields[1]),
                  let cpuPercent = Double(fields[2]),
                  let residentKiB = Int64(fields[3]),
                  let cpuTime = parseCPUTime(fields[4])
            else { return nil }
            return Entry(
                pid: pid,
                parentPID: parentPID,
                cpuPercent: cpuPercent,
                residentBytes: residentKiB * 1024,
                cpuTime: cpuTime
            )
        }
        return ProcessTable(entries: entries, capturedAt: capturedAt)
    }

    /// Parses `ps` CPU time: `[[dd-]hh:]mm:ss.ss`, where macOS lets minutes exceed 59.
    static func parseCPUTime(_ text: Substring) -> TimeInterval? {
        let dayParts = text.split(separator: "-")
        let days = dayParts.count == 2 ? Double(dayParts[0]) : 0
        guard let days, let clock = dayParts.last else { return nil }

        var total = days * 86_400
        var multiplier: Double = 1
        for component in clock.split(separator: ":").reversed() {
            guard let value = Double(component) else { return nil }
            total += value * multiplier
            multiplier *= 60
        }
        return total
    }
}
