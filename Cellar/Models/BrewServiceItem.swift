import Foundation

// MARK: - ServiceStatus

enum ServiceStatus: String, Codable, Hashable, Sendable {
    case started
    case stopped
    case error
    case none
    case unknown

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ServiceStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - BrewServiceItem

struct BrewServiceItem: Identifiable, Codable, Hashable, Sendable {

    // MARK: Properties

    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
    let exitCode: Int?
    let pid: Int?
    let registered: Bool?

    var id: String { name }

    var isRunning: Bool { status == .started }

    // MARK: Actions

    func start() async throws {
        let service = BrewService()
        try await service.startService(name)
    }

    func stop() async throws {
        let service = BrewService()
        try await service.stopService(name)
    }

    func restart() async throws {
        let service = BrewService()
        try await service.restartService(name)
    }

    // MARK: Factory Methods

    static var all: [BrewServiceItem] {
        get async throws {
            let service = BrewService()
            let data = try await service.listServicesData()
            return try JSONDecoder().decode([BrewServiceItem].self, from: data)
        }
    }

    // MARK: Preview

    static var preview: BrewServiceItem {
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

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.status = try container.decodeIfPresent(ServiceStatus.self, forKey: .status) ?? .unknown
        self.user = try container.decodeIfPresent(String.self, forKey: .user)
        self.file = try container.decodeIfPresent(String.self, forKey: .file)
        self.exitCode = try container.decodeIfPresent(Int.self, forKey: .exitCode)
        self.pid = try container.decodeIfPresent(Int.self, forKey: .pid)
        self.registered = try container.decodeIfPresent(Bool.self, forKey: .registered)
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(user, forKey: .user)
        try container.encodeIfPresent(file, forKey: .file)
        try container.encodeIfPresent(exitCode, forKey: .exitCode)
        try container.encodeIfPresent(pid, forKey: .pid)
        try container.encodeIfPresent(registered, forKey: .registered)
    }
}
