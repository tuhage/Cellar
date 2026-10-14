import Foundation

/// A tap together with the installed packages that come from it — what
/// untapping would affect, as opposed to everything the tap offers.
public struct TapUsage: Identifiable, Hashable, Sendable {

    public let tap: Tap
    /// Names of installed formulae from this tap, sorted.
    public let installedFormulae: [String]
    /// Tokens of installed casks from this tap, sorted.
    public let installedCasks: [String]

    public var id: String { tap.id }
    public var name: String { tap.name }
    public var formulaCount: Int { tap.formulaCount }
    public var caskCount: Int { tap.caskCount }
    public var lastCommitAge: TimeInterval { tap.lastCommitAge }

    public var installedCount: Int { installedFormulae.count + installedCasks.count }

    public init(tap: Tap, installedFormulae: [String], installedCasks: [String]) {
        self.tap = tap
        self.installedFormulae = installedFormulae
        self.installedCasks = installedCasks
    }

    /// Formulae the tap offers that aren't installed, by short name.
    public var availableFormulae: [String] {
        Self.available(tap.formulaNames, excluding: installedFormulae)
    }

    /// Casks the tap offers that aren't installed, by short token.
    public var availableCasks: [String] {
        Self.available(tap.caskTokens, excluding: installedCasks)
    }

    private static func available(_ qualifiedNames: [String], excluding installed: [String]) -> [String] {
        let installed = Set(installed)
        return qualifiedNames
            .map(Tap.packageName(fromQualified:))
            .filter { !installed.contains($0) }
            .sorted()
    }

    // MARK: Factory

    /// Matches every installed package to its tap by its fully qualified name.
    public static func usages(of taps: [Tap], formulae: [Formula], casks: [Cask]) -> [TapUsage] {
        let formulaeByTap = Dictionary(grouping: formulae) { formula in
            Tap.tapName(ofPackage: formula.fullName, isCask: false)
        }
        let casksByTap = Dictionary(grouping: casks) { cask in
            Tap.tapName(ofPackage: cask.fullToken.isEmpty ? cask.token : cask.fullToken, isCask: true)
        }
        return taps.map { tap in
            let key = tap.name.lowercased()
            return TapUsage(
                tap: tap,
                installedFormulae: formulaeByTap[key, default: []].map(\.name).sorted(),
                installedCasks: casksByTap[key, default: []].map(\.token).sorted()
            )
        }
    }
}
