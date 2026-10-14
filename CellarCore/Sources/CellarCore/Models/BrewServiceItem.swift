import Foundation

// MARK: - ServiceStatus

/// The status `brew services` reports.
public enum ServiceStatus: String, Codable, Hashable, Sendable, CaseIterable {
    /// Running.
    case started
    /// Loaded, waiting for its next scheduled run (interval or cron).
    case scheduled
    /// Loaded, last run exited normally.
    case stopped
    /// Not loaded in launchd — never started, or stopped with `brew services stop`.
    case none
    /// Loaded, last run exited with an error.
    case error
    /// Loaded, but hasn't run or reported an exit code yet.
    case other
    /// launchd didn't report anything.
    case unknown

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ServiceStatus(rawValue: rawValue) ?? .unknown
    }
}

extension ServiceStatus: Comparable {
    /// Sorts by how much attention a status needs: failures first.
    public static func < (lhs: ServiceStatus, rhs: ServiceStatus) -> Bool {
        lhs.severityRank < rhs.severityRank
    }

    private var severityRank: Int {
        switch self {
        case .error: 0
        case .unknown: 1
        case .started: 2
        case .scheduled: 3
        case .other: 4
        case .stopped: 5
        case .none: 6
        }
    }
}

// MARK: - BrewServiceItem

public struct BrewServiceItem: Identifiable, Codable, Hashable, Sendable {

    // MARK: Properties

    public let name: String
    public let status: ServiceStatus
    public let user: String?
    public let file: String?
    public let exitCode: Int?
    public let pid: Int?
    public let registered: Bool?

    public var id: String { name }

    public var isRunning: Bool { status == .started }
    public var isError: Bool { status == .error }
    public var isStopped: Bool { status == .stopped || status == .none }

    /// Whether this service is registered under `root` (a system LaunchDaemon).
    /// Such services must be managed with elevated privileges.
    public var requiresRoot: Bool { user == "root" }

    /// When the service's current process started, read from the kernel's
    /// process table (works for root-owned processes too).
    public var processStartDate: Date? {
        guard let pid else { return nil }
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, Int32(pid)]
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
    }

    /// Whether launchd relaunches the process when it exits, read from the
    /// service's plist — a force-quit service then comes straight back.
    public var keepsAlive: Bool {
        guard let file, let plist = NSDictionary(contentsOfFile: file),
              let keepAlive = plist["KeepAlive"]
        else { return false }
        if let flag = keepAlive as? Bool { return flag }
        return (keepAlive as? [String: Any])?.isEmpty == false
    }

    // MARK: Init

    public init(
        name: String,
        status: ServiceStatus,
        user: String?,
        file: String?,
        exitCode: Int?,
        pid: Int?,
        registered: Bool?
    ) {
        self.name = name
        self.status = status
        self.user = user
        self.file = file
        self.exitCode = exitCode
        self.pid = pid
        self.registered = registered
    }

    // MARK: Actions

    /// Starts the service and registers it to start at login (boot for root).
    public func start() async throws {
        try await BrewService.shared.startService(name, privileged: requiresRoot)
    }

    /// Starts the service for this session only.
    public func runOnce() async throws {
        try await BrewService.shared.runService(name, privileged: requiresRoot)
    }

    /// Stops the service. With `keepRegistered` it still starts at next login.
    public func stop(keepRegistered: Bool = false) async throws {
        try await BrewService.shared.stopService(name, keepRegistered: keepRegistered, privileged: requiresRoot)
    }

    public func restart() async throws {
        try await BrewService.shared.restartService(name, privileged: requiresRoot)
    }

    /// Kills the service's process with SIGKILL. The PID is looked up again
    /// first: a cached one may since belong to another process.
    public func forceQuit() async throws {
        guard let pid = await Self.currentPIDs(of: [self])[name] else {
            throw BrewError.parsingFailure(context: "\(name) isn’t running")
        }
        try await BrewService.shared.forceQuit(pid: pid, privileged: requiresRoot)
    }

    /// Restarts root services under a single password prompt.
    public static func restartAsRoot(_ services: [BrewServiceItem]) async throws {
        try await BrewService.shared.restartServicesPrivileged(services.map(\.name))
    }

    // MARK: Factory Methods

    public static var all: [BrewServiceItem] {
        get async throws {
            let data = try await BrewService.shared.listServicesData()
            if data.isEmpty { return [] }
            let items = try JSONDecoder().decode([BrewServiceItem].self, from: data)
            let pids = await currentPIDs(of: items)
            return items.map { $0.applyingLaunchdPID(pids[$0.name]) }
        }
    }

    /// Log paths, command and schedule from `brew services info`.
    public var info: ServiceInfo {
        get async throws {
            let data = try await BrewService.shared.serviceInfoData(name)
            guard let info = try JSONDecoder().decode([ServiceInfo].self, from: data).first else {
                throw BrewError.parsingFailure(context: "No info for service \(name)")
            }
            return info
        }
    }

    // MARK: Preview

    public static var preview: BrewServiceItem {
        BrewServiceItem(
            name: "postgresql@16",
            status: .started,
            user: "user",
            file: "/opt/homebrew/opt/postgresql@16/.plist",
            exitCode: 0,
            pid: 12345,
            registered: true
        )
    }
}

// MARK: - launchd

extension BrewServiceItem {

    /// Labels Homebrew registers services under, newest convention last.
    var launchdLabels: [String] {
        ["homebrew.mxcl.\(name)", "sh.brew.\(name)"]
    }

    /// The PID of each running service, read from launchd now — the services
    /// list may come from a cache. Root services live in the system domain,
    /// which can be inspected without elevating.
    public static func currentPIDs(of services: [BrewServiceItem]) async -> [String: Int] {
        let userJobs = services.contains { !$0.requiresRoot }
            ? await SystemCommand.output("/bin/launchctl", ["list"]).map(parseLaunchctlList) ?? [:]
            : [:]
        var pids: [String: Int] = [:]
        for service in services {
            let pid = service.requiresRoot
                ? await service.systemDomainPID()
                : service.launchdLabels.lazy.compactMap { userJobs[$0] }.first
            pids[service.name] = pid
        }
        return pids
    }

    /// Brew's list omits PIDs, and without root it can't see LaunchDaemons,
    /// so it reports a running root service as "none".
    func applyingLaunchdPID(_ pid: Int?) -> BrewServiceItem {
        guard let pid, isRunning || requiresRoot else { return self }
        return BrewServiceItem(
            name: name,
            status: .started,
            user: user,
            file: file,
            exitCode: exitCode,
            pid: pid,
            registered: registered
        )
    }

    private func systemDomainPID() async -> Int? {
        for label in launchdLabels {
            if let output = await SystemCommand.output("/bin/launchctl", ["print", "system/\(label)"]) {
                return Self.parseLaunchctlRuntime(output).pid
            }
        }
        return nil
    }

    struct LaunchctlRuntime: Equatable, Sendable {
        let isRunning: Bool
        let pid: Int?
    }

    /// Parses the relevant fields from `launchctl print` output.
    static func parseLaunchctlRuntime(_ output: String) -> LaunchctlRuntime {
        var state: String?
        var pid: Int?

        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("state =") {
                state = trimmed
                    .dropFirst("state =".count)
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("pid =") {
                let value = trimmed
                    .dropFirst("pid =".count)
                    .trimmingCharacters(in: .whitespaces)
                pid = Int(value)
            }
        }

        return LaunchctlRuntime(isRunning: state == "running" || pid != nil, pid: pid)
    }

    /// Parses `launchctl list` ("PID  Status  Label" rows; "-" when not
    /// running) into the PIDs of running jobs by label.
    static func parseLaunchctlList(_ output: String) -> [String: Int] {
        var pids: [String: Int] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 3, let pid = Int(fields[0]) else { continue }
            pids[String(fields[2])] = pid
        }
        return pids
    }
}

// MARK: - Codable

extension BrewServiceItem {

    private enum CodingKeys: String, CodingKey {
        case name
        case status
        case user
        case file
        case exitCode = "exit_code"
        case pid
        case registered
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decodeIfPresent(ServiceStatus.self, forKey: .status) ?? .unknown
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
        self.file = try container.decodeIfPresent(String.self, forKey: .file)
        self.exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
        self.pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        self.registered = try container.decodeIfPresent(Bool.self, forKey: .registered)
    }
}
