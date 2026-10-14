import SwiftUI
import CellarCore

/// The Casks page.
struct CaskListView: View {
    var body: some View {
        PackageListPage(kind: .cask)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        CaskListView()
            .environment(AppStores())
    }
    .frame(width: 700, height: 500)
}
