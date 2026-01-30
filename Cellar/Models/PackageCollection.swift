import Foundation

// MARK: - PackageCollection

/// A user-defined or built-in collection of Homebrew packages.
///
/// Collections group related formulae and casks under a name (e.g. "Web
/// Development") so they can be installed together or managed as a set.
struct PackageCollection: Identifiable, Codable, Hashable, Sendable {

    // MARK: Data

    let id: UUID
    var name: String
    var icon: String
    var colorName: String
    var packages: [String]
    var casks: [String]
    var description: String?
    let isBuiltIn: Bool

    // MARK: Computed

    var totalCount: Int { packages.count + casks.count }

    // MARK: Initializer

    init(
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

    // MARK: Built-in Collections

    static let builtInCollections: [PackageCollection] = [
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
            casks: [],
            description: "Python-based data science stack.",
            isBuiltIn: true
        ),
        PackageCollection(
            name: "DevOps",
            icon: "server.rack",
            colorName: "orange",
            packages: ["docker", "kubernetes-cli", "terraform"],
            casks: [],
            description: "Infrastructure and container management.",
            isBuiltIn: true
        ),
        PackageCollection(
            name: "Media",
            icon: "photo.on.rectangle",
            colorName: "purple",
            packages: ["ffmpeg", "imagemagick"],
            casks: [],
            description: "Audio, video, and image processing tools.",
            isBuiltIn: true
        ),
    ]

    // MARK: Preview

    static var preview: PackageCollection {
        builtInCollections[0]
    }
}
