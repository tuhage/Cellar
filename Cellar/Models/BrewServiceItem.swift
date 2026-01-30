import Foundation

// MARK: - ServiceStatus

enum ServiceStatus: String, Codable, Hashable, Sendable {
    case started
    case stopped
    case error
    case none
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ServiceStatus(rawValue: rawValue) ?? .unknown
    }
}

// MARK: - BrewServiceItem

struct BrewServiceItem: Identifiable, Codable, Hashable, Sendable {

    // MARK: - Properties

    let name: String
    let status: ServiceStatus
    let user: String?
    let file: String?
    let exitCode: Int?
    let pid: Int?
    let registered: Bool?

    var id: String { name }

    var isRunning: Bool { status == .started }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case name
        case status
        case user
        case file
        case exitCode = "exit_code"
        case pid
        case registered
    }

    // MARK: - Actions

    func start() async throws {
        let process = BrewProcess()
        let output = try await process.run(["services", "start", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func stop() async throws {
        let process = BrewProcess()
        let output = try await process.run(["services", "stop", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    func restart() async throws {
        let process = BrewProcess()
        let output = try await process.run(["services", "restart", name])
        guard output.exitCode == 0 else {
            throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
        }
    }

    // MARK: - Factory Methods

    static var all: [BrewServiceItem] {
        get async throws {
            let process = BrewProcess()
            let output = try await process.run(["services", "list", "--json"])

            guard output.exitCode == 0 else {
                throw BrewError.processFailure(exitCode: output.exitCode, stderr: output.stderr)
            }

            let stdout = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !stdout.isEmpty, let data = stdout.data(using: .utf8) else {
                return []
            }

            do {
                return try JSONDecoder().decode([BrewServiceItem].self, from: data)
            } catch {
                return []
            }
        }
    }

    // MARK: - Preview

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
