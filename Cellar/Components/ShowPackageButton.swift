import SwiftUI
import CellarCore

/// Opens the Formulae or Casks page with the package selected.
struct ShowPackageButton<Label: View>: View {
    let name: String
    let isCask: Bool
    @ViewBuilder let label: Label

    @Environment(PackageStore.self) private var packageStore
    @FocusedValue(\.windowCommands) private var windowCommands

    var body: some View {
        Button {
            if isCask {
                packageStore.selectedCaskId = name
                windowCommands?.navigate(.casks)
            } else {
                packageStore.selectedFormulaId = name
                windowCommands?.navigate(.formulae)
            }
        } label: {
            label
        }
        .disabled(windowCommands == nil)
        .help(Self.title(isCask: isCask))
    }

    static func title(isCask: Bool) -> String {
        isCask ? "Show in Casks" : "Show in Formulae"
    }
}

extension ShowPackageButton where Label == SwiftUI.Label<Text, Image> {
    /// "Show in Formulae" / "Show in Casks".
    init(name: String, isCask: Bool) {
        self.init(name: name, isCask: isCask) {
            SwiftUI.Label(Self.title(isCask: isCask), systemImage: "arrow.forward.circle")
        }
    }
}

#Preview {
    VStack {
        ShowPackageButton(name: "wget", isCask: false)
        ShowPackageButton(name: "firefox", isCask: true)
    }
    .padding()
    .environment(AppStores())
}
