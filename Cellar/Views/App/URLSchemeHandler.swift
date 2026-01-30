import SwiftUI

// MARK: - URLSchemeHandler

/// A view modifier that handles `cellar://` URL scheme deep links.
///
/// Supports navigating to sidebar sections via URLs like:
/// - `cellar://dashboard`
/// - `cellar://formulae`
/// - `cellar://casks`
/// - `cellar://services`
/// - `cellar://search`
/// - `cellar://health`
struct URLSchemeHandler: ViewModifier {
    @Binding var selection: SidebarItem?

    func body(content: Content) -> some View {
        content
            .onOpenURL { url in
                handleURL(url)
            }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "cellar" else { return }

        switch url.host {
        case "dashboard":
            selection = .dashboard
        case "formulae":
            selection = .formulae
        case "casks":
            selection = .casks
        case "services":
            selection = .services
        case "outdated":
            selection = .outdated
        case "search":
            selection = .search
        case "brewfile":
            selection = .brewfile
        case "health":
            selection = .health
        case "security":
            selection = .security
        case "collections":
            selection = .collections
        case "dependencies":
            selection = .dependencies
        case "resources":
            selection = .resources
        case "history":
            selection = .history
        case "projects":
            selection = .projects
        case "comparison":
            selection = .comparison
        case "maintenance":
            selection = .maintenance
        case "settings":
            selection = .settings
        default:
            break
        }
    }
}

// MARK: - View Extension

extension View {
    func urlSchemeHandler(selection: Binding<SidebarItem?>) -> some View {
        modifier(URLSchemeHandler(selection: selection))
    }
}
