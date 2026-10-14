import SwiftUI
import CellarCore

/// Opens the Formulae or Casks page with the package selected.
struct ShowPackageButton<Label: View>: View {
    let package: PackageID
    @ViewBuilder let label: Label

    @Environment(PackageStore.self) private var packageStore

    var body: some View {
        Button {
            Navigator.show(package, in: packageStore)
        } label: {
            label
        }
        .help(Self.title(for: package.kind))
    }

    /// "Show in Formulae" / "Show in Casks".
    static func title(for kind: PackageKind) -> String {
        "Show in \(kind.title)"
    }
}

extension ShowPackageButton where Label == SwiftUI.Label<Text, Image> {
    init(package: PackageID) {
        self.init(package: package) {
            SwiftUI.Label(Self.title(for: package.kind), systemImage: "arrow.forward.circle")
        }
    }
}

#Preview {
    VStack {
        ShowPackageButton(package: PackageID(kind: .formula, name: "wget"))
        ShowPackageButton(package: PackageID(kind: .cask, name: "firefox"))
    }
    .padding()
    .environment(AppStores())
}
