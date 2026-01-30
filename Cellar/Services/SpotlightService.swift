import CoreSpotlight
import CellarCore

nonisolated final class SpotlightService: Sendable {
    static let shared = SpotlightService()

    private static let formulaeDomain = "com.tuhage.Cellar.formulae"
    private static let casksDomain = "com.tuhage.Cellar.casks"

    /// Indexes all formulae and casks in Spotlight.
    func indexAll(formulae: [Formula], casks: [Cask]) async {
        let index = CSSearchableIndex.default()

        // Delete existing entries first
        try? await index.deleteSearchableItems(withDomainIdentifiers: [
            Self.formulaeDomain,
            Self.casksDomain,
        ])

        var items: [CSSearchableItem] = []

        for formula in formulae {
            let attributes = CSSearchableItemAttributeSet(contentType: .item)
            attributes.title = formula.name
            attributes.contentDescription = formula.desc ?? "Homebrew formula"
            attributes.keywords = ["homebrew", "formula", "brew", formula.name]

            let item = CSSearchableItem(
                uniqueIdentifier: "formula:\(formula.name)",
                domainIdentifier: Self.formulaeDomain,
                attributeSet: attributes
            )
            items.append(item)
        }

        for cask in casks {
            let attributes = CSSearchableItemAttributeSet(contentType: .item)
            attributes.title = cask.displayName
            attributes.contentDescription = cask.desc ?? "Homebrew cask"
            attributes.keywords = ["homebrew", "cask", "brew", cask.token]

            let item = CSSearchableItem(
                uniqueIdentifier: "cask:\(cask.token)",
                domainIdentifier: Self.casksDomain,
                attributeSet: attributes
            )
            items.append(item)
        }

        try? await index.indexSearchableItems(items)
    }
}
