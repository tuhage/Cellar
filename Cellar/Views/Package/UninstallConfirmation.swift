import SwiftUI
import CellarCore

/// Packages the user asked to uninstall, waiting for confirmation.
struct UninstallRequest: Identifiable {
    let id = UUID()
    let packages: [PackageType]
    /// Also delete cask app data (`brew uninstall --zap`).
    var removesAppData = false
}

extension View {
    /// Confirms an uninstall and previews what goes with it: formulae that
    /// still need the package and, when removing app data, the files deleted.
    func uninstallConfirmation(_ request: Binding<UninstallRequest?>) -> some View {
        modifier(UninstallConfirmation(request: request))
    }
}

private struct UninstallConfirmation: ViewModifier {
    @Binding var request: UninstallRequest?

    @Environment(PackageStore.self) private var store
    @AppStorage(SettingsKey.confirmsBeforeUninstall) private var confirmsBeforeUninstall = true

    /// How many app data paths the message lists before summarizing.
    private static let listedPathLimit = 5

    func body(content: Content) -> some View {
        content.confirmationDialog(
            request.map(title) ?? "",
            isPresented: Binding(
                get: { request.map(needsConfirmation) ?? false },
                set: { if !$0 { request = nil } }
            ),
            titleVisibility: .visible,
            presenting: request
        ) { request in
            Button(dependents(of: request).isEmpty ? "Uninstall" : "Uninstall Anyway", role: .destructive) {
                perform(request)
            }
            Button("Cancel", role: .cancel) {}
        } message: { request in
            Text(message(for: request))
        }
        .onChange(of: request?.id) {
            guard let request, !needsConfirmation(request) else { return }
            perform(request)
            self.request = nil
        }
    }

    /// The Settings switch only skips safe uninstalls: breaking other
    /// packages or deleting app data always asks.
    private func needsConfirmation(_ request: UninstallRequest) -> Bool {
        confirmsBeforeUninstall || request.removesAppData || !dependents(of: request).isEmpty
    }

    private func perform(_ request: UninstallRequest) {
        Task {
            await store.uninstall(
                request.packages,
                ignoringDependents: !dependents(of: request).isEmpty,
                zap: request.removesAppData
            )
        }
    }

    // MARK: - Text

    private func title(for request: UninstallRequest) -> String {
        let isSingle = request.packages.count == 1
        let subject = isSingle ? request.packages[0].name : "\(request.packages.count) Packages"
        guard request.removesAppData else { return "Uninstall \(subject)?" }
        return "Uninstall \(subject) and Delete \(isSingle ? "Its" : "Their") Data?"
    }

    private func message(for request: UninstallRequest) -> String {
        var paragraphs = [removalSummary(request)]
        let dependents = dependents(of: request)
        if !dependents.isEmpty {
            let names = dependents.map(\.name).formatted(.list(type: .and))
            paragraphs.append("Still used by \(names), which may stop working.")
        }
        if request.removesAppData {
            paragraphs.append(appDataSummary(request))
        }
        return paragraphs.joined(separator: "\n\n")
    }

    private func removalSummary(_ request: UninstallRequest) -> String {
        if request.packages.count == 1, let package = request.packages.first {
            return "Removes \(package.name) \(package.version)."
        }
        return "Removes \(request.packages.map(\.name).formatted(.list(type: .and)))."
    }

    private func appDataSummary(_ request: UninstallRequest) -> String {
        let paths = request.packages.flatMap { package -> [String] in
            guard case .cask(let cask) = package else { return [] }
            return cask.zapPaths
        }
        guard !paths.isEmpty else {
            return "Also deletes the settings, caches and support files Homebrew knows of. This can’t be undone."
        }
        var lines = ["Also deletes these settings, caches and support files. This can’t be undone:"]
        lines += paths.prefix(Self.listedPathLimit)
        if paths.count > Self.listedPathLimit {
            lines.append("and \(paths.count - Self.listedPathLimit) more")
        }
        return lines.joined(separator: "\n")
    }

    /// Installed formulae that need a package being removed and aren't
    /// removed themselves.
    private func dependents(of request: UninstallRequest) -> [Formula] {
        let removed = Set(request.packages.map(\.id))
        var seen = Set<String>()
        return request.packages
            .flatMap { package -> [Formula] in
                guard case .formula(let formula) = package else { return [] }
                return store.dependents(of: formula)
            }
            .filter { !removed.contains(PackageID(kind: .formula, name: $0.name)) && seen.insert($0.name).inserted }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var request: UninstallRequest? = UninstallRequest(packages: [.cask(.preview)], removesAppData: true)

    Button("Uninstall") {
        request = UninstallRequest(packages: [.formula(.preview)])
    }
    .padding()
    .uninstallConfirmation($request)
    .environment(AppStores())
}
