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

    public func start() async throws {
        let service = BrewService()
        try await service.startService(name)
    }

    public func stop() async throws {
        let service = BrewService()
        try await service.stopService(name)
    }

    public func restart() async throws {
        let service = BrewService()
        try await service.restartService(name)
    }

    // MARK: Factory Methods

    public static var all: [BrewServiceItem] {
        get async throws {
            let service = BrewService()
            let data = try await service.listServicesData()
            return try JSONDecoder().decode([BrewServiceItem].self, from: data)
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
