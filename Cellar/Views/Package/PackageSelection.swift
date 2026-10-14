import SwiftUI
import CellarCore

extension View {
    /// What every package page offers for its selection: the inspector, a
    /// toolbar button to show or hide it, the Packages menu commands and the
    /// uninstall confirmation.
    func packageSelection(_ selected: PackageType?, uninstallRequest: Binding<UninstallRequest?>) -> some View {
        modifier(PackageSelectionModifier(selected: selected, uninstallRequest: uninstallRequest))
    }
}

private struct PackageSelectionModifier: ViewModifier {
    let selected: PackageType?
    @Binding var uninstallRequest: UninstallRequest?

    @Environment(PackageStore.self) private var store
    /// One setting for every package page, like a Finder window's preview pane.
    @AppStorage(SettingsKey.showsInspector(.package)) private var showsInspector = true

    func body(content: Content) -> some View {
        content
            .pageInspector(.package, isPresented: $showsInspector, hasContent: selected != nil) {
                if let selected {
                    PackageDetailView(package: selected)
                        // Fresh state per package, so nothing leaks between them.
                        .id(selected.id)
                }
            }
            .uninstallConfirmation($uninstallRequest)
            .focusedSceneValue(
                \.selectedPackage,
                SelectedPackageCommands(package: selected, store: store) { uninstallRequest = $0 }
            )
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var request: UninstallRequest?

    NavigationStack {
        Text("Package list")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .packageSelection(.formula(.preview), uninstallRequest: $request)
    }
    .environment(AppStores())
    .frame(width: 800, height: 500)
}
