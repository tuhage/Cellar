import SwiftUI
import CellarCore

/// Handles `cellar://` URL scheme deep links (e.g., `cellar://formulae`, `cellar://formula/<name>`).
struct URLSchemeHandler: ViewModifier {
    @Binding var selection: SidebarItem?
    @Environment(PackageStore.self) private var packageStore
    @Environment(BrewfileStore.self) private var brewfileStore

    func body(content: Content) -> some View {
        content.onOpenURL { url in handleURL(url) }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "cellar", let host = url.host else { return }

        // Deep links to a specific package: cellar://formula/<name> or cellar://cask/<token>
        if host == "formula" {
            selection = .formulae
            if let name = url.pathComponents.dropFirst().first {
                packageStore.selectedFormulaId = name
            }
            return
        }
        if host == "cask" {
            selection = .casks
            if let token = url.pathComponents.dropFirst().first {
                packageStore.selectedCaskId = token
            }
            return
        }

        // A folder's Brewfile, from Finder's "Open in Cellar": cellar://brewfile?path=<path>
        if host == "brewfile",
           let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
               .queryItems?.first(where: { $0.name == "path" })?.value,
           path.hasPrefix("/") {
            selection = .brewfile
            brewfileStore.open(path: path)
            return
        }

        // Direct sidebar navigation: cellar://dashboard, cellar://services, etc.
        if let item = SidebarItem.resolve(host) {
            selection = item
        }
    }
}

extension View {
    func urlSchemeHandler(selection: Binding<SidebarItem?>) -> some View {
        modifier(URLSchemeHandler(selection: selection))
    }
}
