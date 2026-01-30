import Foundation

// MARK: - PackageCollection

/// A user-defined or built-in collection of Homebrew packages.
///
/// Collections group related formulae and casks under a name (e.g. "Web
/// Development") so they can be installed together or managed as a set.
public struct PackageCollection: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    public let id: UUID
    public var name: String
    public var icon: String
    public var colorName: String
    public var packages: [String]
    public var casks: [String]
    public var description: String?
    public let isBuiltIn: Bool

    // MARK: Computed

    public var totalCount: Int { packages.count + casks.count }

    // MARK: Init

    public init(
        id: UUID = UUID(),
        name: String,
        icon: String,
        colorName: String,
        packages: [String] = [],
        casks: [String] = [],
        description: String? = nil,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.packages = packages
        self.casks = casks
        self.description = description
        self.isBuiltIn = isBuiltIn
    }

    // Backward-compatible decoding: missing keys fall back to defaults.
    public nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.icon = try container.decode(String.self, forKey: .icon)
        self.colorName = try container.decode(String.self, forKey: .colorName)
        self.packages = try container.decodeIfPresent([String].self, forKey: .packages) ?? []
        self.casks = try container.decodeIfPresent([String].self, forKey: .casks) ?? []
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.isBuiltIn = try container.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, icon, colorName, packages, casks, description, isBuiltIn
    }

    // MARK: Built-in Collections

    public static let builtInCollections: [PackageCollection] = [
        PackageCollection(
            name: "Web Development",
            icon: "globe",
            colorName: "blue",
            packages: ["node", "nginx", "redis", "postgresql@16"],
            casks: ["visual-studio-code"],
            description: "Essential tools for web development.",
            isBuiltIn: true
        ),
        PackageCollection(
            name: "iOS Development",
            icon: "iphone",
            colorName: "indigo",
            packages: ["cocoapods", "fastlane", "swiftlint"],
            casks: ["sf-symbols"],
            description: "Tools for building iOS and macOS apps.",
            isBuiltIn: true
        ),
        PackageCollection(
            name: "Data Science",
            icon: "chart.bar.xaxis",
            colorName: "green",
            packages: ["python", "jupyter"],
            description: "Python-based data science stack.",
            isBuiltIn: true
        ),
        PackageCollection(
            name: "DevOps",
            icon: "server.rack",
            colorName: "orange",
            packages: ["docker", "kubernetes-cli", "terraform"],
            description: "Infrastructure and container management.",
            isBuiltIn: true
        ),
        PackageCollection(
            name: "Media",
            icon: "photo.on.rectangle",
            colorName: "purple",
            packages: ["ffmpeg", "imagemagick"],
            description: "Audio, video, and image processing tools.",
            isBuiltIn: true
        ),
    ]

    // MARK: Preview

    public static var preview: PackageCollection {
        builtInCollections[0]
    }
}
