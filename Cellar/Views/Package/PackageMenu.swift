import SwiftUI
import CellarCore

// MARK: - PackageMenu

/// The context menu of every package list, acting on the selection.
struct PackageMenu: View {
    let packages: [PackageType]
    /// Opens the inspector for a single package.
    let showDetails: () -> Void
    let requestUninstall: (UninstallRequest) -> Void

    @Environment(PackageStore.self) private var store

    var body: some View {
        if packages.count == 1, let package = packages.first {
            singlePackageItems(package)
        } else if packages.count > 1 {
            selectionItems
        }
    }

    // MARK: - One Package

    @ViewBuilder
    private func singlePackageItems(_ package: PackageType) -> some View {
        Group {
            if let primary = PackagePrimaryAction(package: package, store: store) {
                Button(primary.title) {
                    Task { await primary.perform() }
                }
            }
            if case .formula(let formula) = package, formula.isInstalled {
                Button(formula.pinned ? "Unpin" : "Pin") {
                    Task { await store.setPinned(!formula.pinned, for: [formula]) }
                }
            }
        }
        .disabled(store.isBusy(package))

        PackageMoreMenuItems(package: package)

        Divider()

        Button("Show Details", action: showDetails)

        if package.isInstalled {
            Divider()
            PackageUninstallButtons(package: package, requestUninstall: requestUninstall)
        }
    }

    // MARK: - Several Packages

    @ViewBuilder
    private var selectionItems: some View {
        let installed = packages.filter { $0.isInstalled && !store.isBusy($0) }
        let upgradable = installed.filter(\.canUpgrade)
        let formulae = installed.compactMap { package -> Formula? in
            if case .formula(let formula) = package { return formula }
            return nil
        }

        if !upgradable.isEmpty {
            Button("Upgrade \(String.count(upgradable.count, "Package"))") {
                Task { await store.upgrade(upgradable) }
            }
        }
        if formulae.contains(where: { !$0.pinned }) {
            Button("Pin \(Self.formulae(formulae.count(where: { !$0.pinned })))") {
                Task { await store.setPinned(true, for: formulae) }
            }
        }
        if formulae.contains(where: \.pinned) {
            Button("Unpin \(Self.formulae(formulae.count(where: \.pinned)))") {
                Task { await store.setPinned(false, for: formulae) }
            }
        }

        Divider()

        Button("Uninstall \(String.count(installed.count, "Package"))\u{2026}", role: .destructive) {
            requestUninstall(UninstallRequest(packages: installed))
        }
        .disabled(installed.isEmpty)
    }

    /// "3 Formulae" — an irregular plural, so not `String.count`.
    private static func formulae(_ count: Int) -> String {
        "\(count) \(PackageKind.formula.noun(count: count).capitalized)"
    }
}

// MARK: - Shared Items

/// The main thing to do with a package: install it, or upgrade it —
/// unpinning a pinned formula first, since brew refuses to upgrade it.
struct PackagePrimaryAction {
    let title: String
    /// The title with the package name, for tooltips and VoiceOver.
    let help: String
    let systemImage: String
    let perform: @MainActor () async -> Void

    /// `nil` when the package is installed and up to date.
    init?(package: PackageType, store: PackageStore) {
        if !package.isInstalled {
            title = "Install"
            help = "Install \(package.name)"
            systemImage = "arrow.down.circle"
            perform = { await store.install(package) }
        } else if case .formula(let formula) = package, formula.pinned, formula.outdated {
            title = "Unpin and Upgrade"
            help = "Unpin \(package.name) and upgrade it to \(package.latestVersion)"
            systemImage = "pin.slash"
            perform = { await store.unpinAndUpgrade(formula) }
        } else if package.isOutdated {
            title = "Upgrade to \(package.latestVersion)"
            help = "Upgrade \(package.name) to \(package.latestVersion)"
            systemImage = "arrow.up.circle"
            perform = { await store.upgrade(package) }
        } else {
            return nil
        }
    }
}

/// Secondary actions: the inspector's More menu, also part of the context
/// menu.
struct PackageMoreMenuItems: View {
    let package: PackageType

    @Environment(PackageStore.self) private var store

    var body: some View {
        if package.isInstalled {
            Group {
                if case .cask(let cask) = package, cask.autoUpdates {
                    Button("Force Upgrade") {
                        Task { await store.forceUpgrade(cask) }
                    }
                    .help("Upgrade with Homebrew even though the app updates itself")
                }
                Button("Reinstall") {
                    Task { await store.reinstall(package) }
                }
            }
            .disabled(store.isBusy(package))

            Divider()

            if case .cask(let cask) = package, cask.appURL != nil {
                Button("Open App", action: package.openApp)
            }
            if package.fileURL != nil {
                Button("Reveal in Finder", action: package.revealInFinder)
            }
        }
        if package.homepageURL != nil {
            Button("Open Homepage", action: package.openHomepage)
        }
        Button("Copy Install Command", action: package.copyInstallCommand)
    }
}

/// Uninstall, plus removing app data for casks.
struct PackageUninstallButtons: View {
    let package: PackageType
    let requestUninstall: (UninstallRequest) -> Void

    @Environment(PackageStore.self) private var store

    var body: some View {
        Group {
            Button("Uninstall\u{2026}", role: .destructive) {
                requestUninstall(UninstallRequest(packages: [package]))
            }
            if package.kind == .cask {
                Button("Uninstall and Remove App Data\u{2026}", role: .destructive) {
                    requestUninstall(UninstallRequest(packages: [package], removesAppData: true))
                }
            }
        }
        .disabled(store.isBusy(package))
    }
}

// MARK: - Menu Commands

extension SelectedPackageCommands {

    /// Menu bar commands for an installed package; `nil` otherwise, since
    /// they upgrade, pin and uninstall.
    init?(package: PackageType?, store: PackageStore, requestUninstall: @escaping (UninstallRequest) -> Void) {
        guard let package, package.isInstalled else { return nil }
        let formula: Formula? = if case .formula(let formula) = package { formula } else { nil }
        self.init(
            name: package.name,
            isBusy: store.isBusy(package),
            canUpgrade: package.canUpgrade,
            isPinned: formula?.pinned,
            upgrade: { Task { await store.upgrade(package) } },
            togglePin: {
                guard let formula else { return }
                Task { await store.setPinned(!formula.pinned, for: [formula]) }
            },
            uninstall: { requestUninstall(UninstallRequest(packages: [package])) }
        )
    }
}

// MARK: - Preview

#Preview {
    Menu("Actions") {
        PackageMenu(packages: [.formula(.preview)], showDetails: {}, requestUninstall: { _ in })
    }
    .padding()
    .environment(AppStores())
}
