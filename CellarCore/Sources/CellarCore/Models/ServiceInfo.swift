import Foundation

// MARK: - ServiceInfo

/// Details of one service from `brew services info <name> --json` that the
/// services list doesn't include.
public struct ServiceInfo: Codable, Hashable, Sendable {

    // MARK: Properties

    public let name: String
    /// The launchd label, such as `homebrew.mxcl.postgresql@17`.
    public let label: String?
    /// Whether the service starts at login (at boot for root services).
    public let registered: Bool?
    public let command: String?
    public let workingDirectory: String?
    public let logPath: String?
    public let errorLogPath: String?
    /// Seconds between runs, for services that run on an interval.
    public let interval: Int?
    /// The cron schedule, for services that run at set times.
    public let cron: String?

    /// Where the service writes errors; many services log both streams to one file.
    public var errorLogOrLogPath: String? {
        errorLogPath ?? logPath
    }

    public init(
        name: String,
        label: String? = nil,
        registered: Bool? = nil,
        command: String? = nil,
        workingDirectory: String? = nil,
        logPath: String? = nil,
        errorLogPath: String? = nil,
        interval: Int? = nil,
        cron: String? = nil
    ) {
        self.name = name
        self.label = label
        self.registered = registered
        self.command = command
        self.workingDirectory = workingDirectory
        self.logPath = logPath
        self.errorLogPath = errorLogPath
        self.interval = interval
        self.cron = cron
    }

    // MARK: Logs

    /// The last lines of the error log, or `nil` when it doesn't exist or
    /// isn't readable (root services often log to root-owned files).
    public func recentErrorLines(_ count: Int = 20) async -> [String]? {
        guard let path = errorLogOrLogPath else { return nil }
        return Self.lastLines(ofFileAt: path, count: count)
    }

    /// Reads only the end of the file, so a huge log costs no more than a small one.
    static func lastLines(ofFileAt path: String, count: Int, maxBytes: UInt64 = 64 * 1024) -> [String]? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        let start = size > maxBytes ? size - maxBytes : 0
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.readToEnd()
        else { return [] }

        var lines = String(decoding: data, as: UTF8.self)
            .split(whereSeparator: \.isNewline)
            .map(String.init)
        if start > 0, !lines.isEmpty {
            lines.removeFirst() // cut mid-line
        }
        return Array(lines.suffix(count))
    }

    // MARK: Preview

    public static var preview: ServiceInfo {
        ServiceInfo(
            name: "postgresql@16",
            label: "homebrew.mxcl.postgresql@16",
            registered: true,
            command: "/opt/homebrew/opt/postgresql@16/bin/postgres -D /opt/homebrew/var/postgresql@16",
            workingDirectory: "/opt/homebrew",
            logPath: "/opt/homebrew/var/log/postgresql@16.log",
            errorLogPath: "/opt/homebrew/var/log/postgresql@16.log"
        )
    }
}

// MARK: - Codable

extension ServiceInfo {

    private enum CodingKeys: String, CodingKey {
        case name
        case label = "service_name"
        case registered
        case command
        case workingDirectory = "working_dir"
        case logPath = "log_path"
        case errorLogPath = "error_log_path"
        case interval
        case cron
    }

    /// Schedule fields are decoded leniently: their shape varies between
    /// Homebrew versions and shouldn't make the whole info unreadable.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        registered = try container.decodeIfPresent(Bool.self, forKey: .registered)
        command = try container.decodeIfPresent(String.self, forKey: .command)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        logPath = try container.decodeIfPresent(String.self, forKey: .logPath)
        errorLogPath = try container.decodeIfPresent(String.self, forKey: .errorLogPath)
        interval = try? container.decodeIfPresent(Int.self, forKey: .interval)
        cron = try? container.decodeIfPresent(String.self, forKey: .cron)
    }
}
