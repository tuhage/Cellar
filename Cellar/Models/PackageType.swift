import AppKit
import CellarCore

// MARK: - PackageKind

/// Which list a package belongs to.
nonisolated enum PackageKind: String, CaseIterable, Sendable {
    case formula
    case cask

    /// "Formulae" — the page title.
    var title: String {
        switch self {
        case .formula: "Formulae"
        case .cask: "Casks"
        }
    }

    /// "formula" or "formulae", for sentences.
    func noun(count: Int) -> String {
        switch self {
        case .formula: count == 1 ? "formula" : "formulae"
        case .cask: count == 1 ? "cask" : "casks"
        }
    }

    var systemImage: String {
        switch self {
        case .formula: "terminal"
        case .cask: "macwindow"
        }
    }
}

// MARK: - PackageID

/// Identifies a package across kinds: a formula and a cask can share a name.
nonisolated struct PackageID: Hashable, Sendable {
    let kind: PackageKind
    /// The formula name or cask token brew uses.
    let name: String
}

// MARK: - PackageType

/// A formula or a cask, so pages, menus and the inspector treat both alike.
nonisolated enum PackageType: Identifiable, Hashable, Sendable {
    case formula(Formula)
    case cask(Cask)

    var id: PackageID { PackageID(kind: kind, name: identifier) }

    var kind: PackageKind {
        switch self {
        case .formula: .formula
        case .cask: .cask
        }
    }

    /// The formula name or cask token — what brew and activity targets use.
    var identifier: String {
        switch self {
        case .formula(let formula): formula.name
        case .cask(let cask): cask.token
        }
    }

    /// What people call it: the formula name or the cask's app name.
    var name: String {
        switch self {
        case .formula(let formula): formula.name
        case .cask(let cask): cask.displayName
        }
    }

    /// The installed version, or the latest one for a package that isn't
    /// installed.
    var version: String {
        switch self {
        case .formula(let formula): formula.version
        case .cask(let cask): cask.installed ?? cask.version
        }
    }

    /// The version an upgrade installs.
    var latestVersion: String {
        switch self {
        case .formula(let formula): formula.latestVersion ?? "latest"
        case .cask(let cask): cask.version
        }
    }

    var description: String? {
        switch self {
        case .formula(let formula): formula.desc
        case .cask(let cask): cask.desc
        }
    }

    var homepageURL: URL? {
        switch self {
        case .formula(let formula): formula.homepage.flatMap(URL.init(string:))
        case .cask(let cask): cask.homepage.flatMap(URL.init(string:))
        }
    }

    var caveats: String? {
        let text = switch self {
        case .formula(let formula): formula.caveats
        case .cask(let cask): cask.caveats
        }
        return text.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 }
    }

    var installCommand: String {
        switch self {
        case .formula(let formula): formula.installCommand
        case .cask(let cask): cask.installCommand
        }
    }

    var isInstalled: Bool {
        switch self {
        case .formula(let formula): formula.isInstalled
        case .cask(let cask): cask.isInstalled
        }
    }

    var isOutdated: Bool {
        switch self {
        case .formula(let formula): formula.outdated
        case .cask(let cask): cask.outdated
        }
    }

    var isDeprecated: Bool {
        switch self {
        case .formula(let formula): formula.deprecated
        case .cask(let cask): cask.deprecated
        }
    }

    /// Pinned formulae are skipped by brew upgrades; casks can't be pinned.
    var isPinned: Bool {
        if case .formula(let formula) = self { return formula.pinned }
        return false
    }

    /// Search results past the first few carry only a name.
    var isNameOnly: Bool {
        !isInstalled && version == "unknown"
    }

    /// Outdated and upgradable as is — brew refuses to upgrade pinned formulae.
    var canUpgrade: Bool {
        isOutdated && !isPinned
    }

    /// What Reveal in Finder shows: the formula's keg or the cask's app.
    var fileURL: URL? {
        switch self {
        case .formula(let formula): formula.kegURL
        case .cask(let cask): cask.appURL
        }
    }

    /// The package's step in an Upgrade All batch.
    @MainActor var upgradeStep: BrewOperation.Step {
        switch self {
        case .formula(let formula): BrewOperation.Step(formula: formula)
        case .cask(let cask): BrewOperation.Step(cask: cask)
        }
    }

    /// Whether the name, brew name, tap-qualified name or description
    /// contains `query`.
    func matches(_ query: String) -> Bool {
        let fields: [String?] = switch self {
        case .formula(let formula): [formula.name, formula.fullName, formula.desc]
        case .cask(let cask): [cask.token, cask.fullToken, cask.desc] + cask.names
        }
        return fields.contains { $0?.localizedCaseInsensitiveContains(query) == true }
    }
}

// MARK: - Desktop Actions

@MainActor
extension PackageType {

    func openHomepage() {
        guard let homepageURL else { return }
        NSWorkspace.shared.open(homepageURL)
    }

    func copyInstallCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(installCommand, forType: .string)
    }

    func revealInFinder() {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    /// Opens the cask's app, if it installs one.
    func openApp() {
        guard case .cask(let cask) = self, let appURL = cask.appURL else { return }
        NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration())
    }
}
