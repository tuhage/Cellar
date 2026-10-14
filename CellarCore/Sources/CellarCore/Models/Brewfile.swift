import Foundation

// MARK: - Brewfile

/// A Brewfile Cellar keeps in its list.
///
/// `.mac` Brewfiles describe this Mac's whole setup (`~/Brewfile`): Cellar
/// exports into them and cleans up what they don't list. `.project`
/// Brewfiles live in a project folder and list what that project needs,
/// plus the services it runs while you work on it.
public struct Brewfile: Identifiable, Codable, Hashable, Sendable {

    public enum Kind: String, Codable, Sendable {
        case mac
        case project
    }

    // MARK: Data

    public let id: UUID
    public var kind: Kind
    public var name: String
    /// The Brewfile itself, not its folder.
    public var path: String
    /// The file's modification date right after Cellar last exported into
    /// it; a later date means it was edited since.
    public var lastExported: Date?
    /// Services a project starts together when activated.
    public var services: [String]
    /// Packages from the old Projects page that couldn't be written to the
    /// Brewfile yet because its folder didn't exist.
    public var pendingPackages: [String]

    // MARK: Init

    public init(
        id: UUID = UUID(),
        kind: Kind,
        name: String,
        path: String,
        lastExported: Date? = nil,
        services: [String] = [],
        pendingPackages: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.path = path
        self.lastExported = lastExported
        self.services = services
        self.pendingPackages = pendingPackages
    }

    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        lastExported = try container.decodeIfPresent(Date.self, forKey: .lastExported)
        services = try container.decodeIfPresent([String].self, forKey: .services) ?? []
        pendingPackages = try container.decodeIfPresent([String].self, forKey: .pendingPackages) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, name, path, lastExported, services, pendingPackages
    }

    // MARK: Location

    /// `~/Brewfile`, the Brewfile of the "This Mac" entry.
    public static var defaultMacPath: String { "\(NSHomeDirectory())/Brewfile" }

    /// Whether `path` is `~/Brewfile`, however it is spelled.
    public static func isDefaultMacPath(_ path: String) -> Bool {
        URL(fileURLWithPath: path).resolvingSymlinksInPath() == URL(fileURLWithPath: defaultMacPath).resolvingSymlinksInPath()
    }

    /// The Brewfile for a dropped or chosen item: a folder's `Brewfile`, or
    /// the file itself.
    public static func path(forFileOrFolder url: URL) -> String {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        let isFolder = exists ? isDirectory.boolValue : url.hasDirectoryPath
        return isFolder ? url.appendingPathComponent("Brewfile").path : url.path
    }

    /// A name for a newly added Brewfile: the folder's name for a file
    /// called `Brewfile`, otherwise the file's own name.
    public static func suggestedName(forPath path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent == "Brewfile" ? url.deletingLastPathComponent().lastPathComponent : url.lastPathComponent
    }

    public var url: URL { URL(fileURLWithPath: path) }
    public var folderURL: URL { url.deletingLastPathComponent() }
    public var folderExists: Bool { FileManager.default.fileExists(atPath: folderURL.path) }
    public var exists: Bool { FileManager.default.fileExists(atPath: path) }

    /// The path with the home folder shortened to `~`.
    public var displayPath: String { (path as NSString).abbreviatingWithTildeInPath }

    /// Where `backUp()` keeps the previous version.
    public var backupURL: URL { URL(fileURLWithPath: path + ".bak") }

    public var modificationDate: Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    /// Whether exporting would replace something Cellar didn't write: the
    /// file was edited after the last export, or was never exported into.
    public var hasChangesSinceExport: Bool {
        guard let modified = modificationDate else { return false }
        guard let lastExported else { return true }
        return modified.timeIntervalSince(lastExported) > 1
    }

    // MARK: File Tasks

    public func read() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    public func write(_ text: String) throws {
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Creates the file with a header comment. An existing file is never
    /// touched; returns whether a file was created.
    @discardableResult
    public func createIfMissing() throws -> Bool {
        guard !exists else { return false }
        let header = "# Brewfile\n# Created \(Date().formatted(date: .abbreviated, time: .omitted))\n"
        try write(header)
        return true
    }

    /// Copies the file to `Brewfile.bak` next to it, replacing an older copy.
    public func backUp() throws {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.removeItem(at: backupURL)
        }
        try fileManager.copyItem(at: url, to: backupURL)
    }

    public func moveToTrash() throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// Adds `brew` lines for packages the file doesn't list yet, creating
    /// the file if needed. Returns the packages that were added.
    @discardableResult
    public func addFormulae(_ names: [String]) throws -> [String] {
        try createIfMissing()
        let text = try read()
        let content = BrewfileContent.parse(from: text)
        let added = names.filter { !content.contains(keyword: "brew", name: $0) }
        guard !added.isEmpty else { return [] }
        let lines = added.map { BrewfileContent.Entry(keyword: "brew", name: $0).rawLine }
        try write(BrewfileContent.appending(lines, to: text))
        return added
    }

    // MARK: Preview

    public static var preview: Brewfile {
        Brewfile(
            kind: .project,
            name: "My Web App",
            path: "/Users/user/Projects/myapp/Brewfile",
            services: ["postgresql@16", "redis"]
        )
    }

    public static var previewList: [Brewfile] {
        [
            Brewfile(kind: .mac, name: "This Mac", path: defaultMacPath, lastExported: Date(timeIntervalSince1970: 1_768_746_915)),
            preview,
        ]
    }
}
