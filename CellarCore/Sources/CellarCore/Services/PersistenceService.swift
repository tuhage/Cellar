import Foundation

public nonisolated final class PersistenceService: Sendable {
    private let baseURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.baseURL = appSupport.appendingPathComponent("Cellar", isDirectory: true)
    }

    // MARK: - Read

    public func load<T: Decodable>(_ type: T.Type, from fileName: String) throws -> T {
        let url = fileURL(for: fileName)
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }

    public func loadOrDefault<T: Decodable>(_ type: T.Type, from fileName: String, default defaultValue: T) -> T {
        (try? load(type, from: fileName)) ?? defaultValue
    }

    // MARK: - Write

    public func save<T: Encodable>(_ value: T, to fileName: String) throws {
        try ensureDirectoryExists()
        let url = fileURL(for: fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Delete

    public func delete(fileName: String) throws {
        let url = fileURL(for: fileName)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    public func exists(fileName: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(for: fileName).path)
    }

    // MARK: - Private

    private func fileURL(for fileName: String) -> URL {
        baseURL.appendingPathComponent(fileName)
    }

    private func ensureDirectoryExists() throws {
        guard !FileManager.default.fileExists(atPath: baseURL.path) else { return }
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }
}
