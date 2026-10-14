import SwiftUI
import CellarCore

/// The Formulae page.
struct FormulaListView: View {
    var body: some View {
        PackageListPage(kind: .formula)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FormulaListView()
            .environment(AppStores())
    }
    .frame(width: 700, height: 500)
}
