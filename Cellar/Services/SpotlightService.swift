import CoreSpotlight
import CellarCore

nonisolated final class SpotlightService: Sendable {
    static let shared = SpotlightService()

    private static let formulaeDomain = "com.tuhage.Cellar.formulae"
    private static let casksDomain = "com.tuhage.Cellar.casks"

    func indexAll(formulae: [Formula], casks: [Cask]) async {
        let index = CSSearchableIndex.default()

        try? await index.deleteSearchableItems(withDomainIdentifiers: [
            Self.formulaeDomain,
            Self.casksDomain,
        ])

        let formulaeItems = formulae.map { formula in
            makeItem(
                identifier: "formula:\(formula.name)",
                domain: Self.formulaeDomain,
                title: formula.name,
                description: formula.desc ?? "Homebrew formula",
                keywords: ["homebrew", "formula", "brew", formula.name]
            )
        }

        let caskItems = casks.map { cask in
            makeItem(
                identifier: "cask:\(cask.token)",
                domain: Self.casksDomain,
                title: cask.displayName,
                description: cask.desc ?? "Homebrew cask",
                keywords: ["homebrew", "cask", "brew", cask.token]
            )
        }

        try? await index.indexSearchableItems(formulaeItems + caskItems)
    }

    private func makeItem(
        identifier: String,
        domain: String,
        title: String,
        description: String,
        keywords: [String]
    ) -> CSSearchableItem {
        let attributes = CSSearchableItemAttributeSet(contentType: .item)
        attributes.title = title
        attributes.contentDescription = description
        attributes.keywords = keywords
        return CSSearchableItem(uniqueIdentifier: identifier, domainIdentifier: domain, attributeSet: attributes)
    }
}
