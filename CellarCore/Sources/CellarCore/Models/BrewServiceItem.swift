import Foundation

// MARK: - ServiceStatus

public enum ServiceStatus: String, Codable, Hashable, Sendable {
    case started
    case stopped
    case error
    case none
    case unknown

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ServiceStatus(rawValue: rawValue) ?? .unknown
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

    public func start(privileged: Bool = false) async throws {
        try await BrewService.shared.startService(name, privileged: privileged)
    }

    public func stop(privileged: Bool = false) async throws {
        try await BrewService.shared.stopService(name, privileged: privileged)
    }

    public func restart(privileged: Bool = false) async throws {
        try await BrewService.shared.restartService(name, privileged: privileged)
    }

    public func kill() async throws {
        try await BrewService.shared.killService(name)
    }

    // MARK: Factory Methods

    public static var all: [BrewServiceItem] {
        get async throws {
            let data = try await BrewService.shared.listServicesData()
            if data.isEmpty { return [] }
            var items = try JSONDecoder().decode([BrewServiceItem].self, from: data)

            for index in items.indices {
                let item = items[index]

                // Non-privileged `brew services list` only inspects the current
                // user's LaunchAgents. Root services live in the system domain,
                // so Homebrew can report "none" even while the daemon is running.
                if item.requiresRoot,
                   let runtime = await resolveSystemRuntimeViaLaunchctl(for: item.name),
                   runtime.isRunning {
                    items[index] = item.withRuntimeState(
                        status: .started,
                        pid: runtime.pid ?? item.pid
                    )
                    continue
                }

                // Homebrew sometimes omits the pid for running user services.
                if item.isRunning,
                   item.pid == nil,
                   let resolved = await resolvePIDViaLaunchctl(for: item.name) {
                    items[index] = item.withRuntimeState(status: item.status, pid: resolved)
                }
            }

            return items
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

// MARK: - PID Resolution

extension BrewServiceItem {

    /// Returns a copy with launchctl's runtime state applied.
    func withRuntimeState(status: ServiceStatus, pid: Int?) -> BrewServiceItem {
        BrewServiceItem(
            name: name,
            status: status,
            user: user,
            file: file,
            exitCode: exitCode,
            pid: pid,
            registered: registered
        )
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

    /// Root Homebrew services are registered in launchd's system domain, which
    /// can be inspected without elevating the Cellar process.
    private static func resolveSystemRuntimeViaLaunchctl(
        for serviceName: String
    ) async -> LaunchctlRuntime? {
        let label = "homebrew.mxcl.\(serviceName)"

        return await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["print", "system/\(label)"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: parseLaunchctlRuntime(output))
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// Queries `launchctl list` for the service's PID using the
    /// standard Homebrew label convention (`homebrew.mxcl.<name>`).
    private static func resolvePIDViaLaunchctl(for serviceName: String) async -> Int? {
        let label = "homebrew.mxcl.\(serviceName)"

        return await withCheckedContinuation { continuation in
            let process = Process()
            let pipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            process.arguments = ["list", label]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice

            process.terminationHandler = { _ in
                guard process.terminationStatus == 0 else {
                    continuation.resume(returning: nil)
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: nil)
                    return
                }

                // launchctl output contains a line like:  "PID" = 12345;
                for line in output.components(separatedBy: "\n") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("\"PID\"") {
                        let parts = trimmed.components(separatedBy: "=")
                        if parts.count >= 2 {
                            let value = parts[1]
                                .trimmingCharacters(in: .whitespaces)
                                .replacingOccurrences(of: ";", with: "")
                            if let pid = Int(value) {
                                continuation.resume(returning: pid)
                                return
                            }
                        }
                    }
                }

                continuation.resume(returning: nil)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
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
