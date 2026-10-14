import SwiftUI
import CellarCore

/// Handles `cellar://` links:
/// - `cellar://<page>` — a sidebar page, e.g. `cellar://services`
/// - `cellar://formula/<name>`, `cellar://cask/<token>` — a package
/// - `cellar://brewfile?path=<path>` — a folder's Brewfile, from Finder
struct URLSchemeHandler: ViewModifier {
    @Environment(PackageStore.self) private var packageStore
    @Environment(BrewfileStore.self) private var brewfileStore

    func body(content: Content) -> some View {
        content.onOpenURL { url in handleURL(url) }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "cellar", let host = url.host else { return }

        if let kind = PackageKind(rawValue: host) {
            if let name = url.pathComponents.dropFirst().first {
                Navigator.show(PackageID(kind: kind, name: name), in: packageStore)
            } else {
                Navigator.show(kind.sidebarItem)
            }
        } else if host == "brewfile", let path = queryPath(of: url) {
            Navigator.show(.brewfile)
            brewfileStore.open(path: path)
        } else if let item = SidebarItem.resolve(host) {
            Navigator.show(item)
        }
    }

    /// The absolute path in `?path=`.
    private func queryPath(of url: URL) -> String? {
        let path = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "path" }?.value
        return path?.hasPrefix("/") == true ? path : nil
    }
}

extension View {
    func urlSchemeHandler() -> some View {
        modifier(URLSchemeHandler())
    }
}
