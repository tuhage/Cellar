import SwiftUI
import CellarCore

/// Whether package pages show the inspector for their selection — one
/// setting for all of them, like a Finder window's preview pane.
enum PackageInspector {
    static let visibilityKey = "showsPackageInspector"
}

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
    @AppStorage(PackageInspector.visibilityKey) private var showsInspector = true

    func body(content: Content) -> some View {
        content
            .inspector(isPresented: Binding(
                get: { showsInspector && selected != nil },
                set: { showsInspector = $0 }
            )) {
                if let selected {
                    PackageDetailView(package: selected)
                        // Fresh state per package, so nothing leaks between them.
                        .id(selected.id)
                        .inspectorColumnWidth(min: 360, ideal: 400, max: 560)
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showsInspector.toggle()
                    } label: {
                        Label("Inspector", systemImage: "sidebar.trailing")
                    }
                    .help(showsInspector ? "Hide Inspector" : "Show Inspector")
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
