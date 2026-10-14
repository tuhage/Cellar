import SwiftUI
import CellarCore

/// The inspector of the package pages: what a package is, its state and
/// setup notes, its dependencies, and the actions for it.
struct PackageDetailView: View {
    let package: PackageType

    @Environment(PackageStore.self) private var store
    @Environment(ActivityStore.self) private var activityStore
    @AppStorage("selectedSidebarItem") private var sidebarSelection = SidebarItem.dashboard.rawValue
    @State private var uninstallRequest: UninstallRequest?
    /// Details for a search result that arrived with a name only.
    @State private var fetchedDetails: PackageType?

    /// Once installed, the package itself is current again.
    private var shown: PackageType {
        package.isNameOnly ? fetchedDetails ?? package : package
    }

    private var isBusy: Bool { store.isBusy(shown) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.section) {
                header
                actions
                if let caveats = shown.caveats {
                    caveatsSection(caveats)
                }
                infoGrid
                    .padding(Spacing.cardPadding)
                    .cardStyle()
                if case .formula(let formula) = shown {
                    dependencySections(formula)
                }
            }
            .padding(Spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .uninstallConfirmation($uninstallRequest)
        .task { await fetchDetailsIfNeeded() }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.sectionContent) {
            Image(systemName: shown.kind.systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: IconSize.smallIcon, height: IconSize.smallIcon)
                .background(tint.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.small))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.compact) {
                Text(shown.name)
                    .font(.title2.weight(.semibold))
                    .textSelection(.enabled)
                if let description = shown.description {
                    Text(description)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                PackageBadges(package: shown)
            }
        }
    }

    private var tint: Color {
        shown.kind == .formula ? .blue : .purple
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            primaryButton

            HStack(spacing: Spacing.item) {
                if case .formula(let formula) = shown, formula.isInstalled {
                    Button {
                        Task { await store.setPinned(!formula.pinned, for: [formula]) }
                    } label: {
                        Label(formula.pinned ? "Unpin" : "Pin", systemImage: formula.pinned ? "pin.slash" : "pin")
                    }
                    .help(formula.pinned ? "Let upgrades include \(formula.name) again" : "Keep \(formula.name) at \(formula.version) during upgrades")
                    .disabled(isBusy)
                }

                if shown.isInstalled {
                    uninstallButton
                        .disabled(isBusy)
                }

                Menu {
                    PackageMoreMenuItems(package: shown)
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More actions")
            }
        }
    }

    /// Install or upgrade, or what is happening to the package right now.
    @ViewBuilder
    private var primaryButton: some View {
        if isBusy, let activity = PackageActivity(shown, activityStore: activityStore) {
            Button {} label: {
                Label {
                    Text(activity.label)
                } icon: {
                    ProgressView()
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(true)
        } else if let primary = PackagePrimaryAction(package: shown, store: store) {
            Button {
                Task { await primary.perform() }
            } label: {
                Label(primary.title, systemImage: primary.systemImage)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(shown.isInstalled ? .orange : .accentColor)
            .help(primary.help)
        }
    }

    /// Casks also offer removing the app's data from the button's menu.
    @ViewBuilder
    private var uninstallButton: some View {
        let label = Label("Uninstall\u{2026}", systemImage: "trash")
        let uninstall = { uninstallRequest = UninstallRequest(packages: [shown]) }
        if shown.kind == .cask {
            Menu {
                Button("Uninstall and Remove App Data\u{2026}", role: .destructive) {
                    uninstallRequest = UninstallRequest(packages: [shown], removesAppData: true)
                }
            } label: {
                label
            } primaryAction: {
                uninstall()
            }
            .fixedSize()
        } else {
            Button(role: .destructive, action: uninstall) { label }
        }
    }

    // MARK: - Caveats

    private func caveatsSection(_ caveats: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            Label("Caveats", systemImage: "info.circle")
                .font(.headline)
            Text(caveats)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.sectionContent)
                .cardStyle(cornerRadius: CornerRadius.card)
        }
    }

    // MARK: - Info

    private var infoGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Spacing.sectionContent, verticalSpacing: Spacing.item) {
            infoRow("Identifier") {
                Text(shown.identifier)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }
            infoRow(shown.isInstalled ? "Installed" : "Version") {
                Text(shown.version)
                    .fontDesign(.monospaced)
                    .textSelection(.enabled)
            }
            if shown.isOutdated {
                infoRow("Latest") {
                    Text(shown.latestVersion)
                        .fontDesign(.monospaced)
                        .foregroundStyle(.orange)
                }
            }
            if let homepage = shown.homepageURL {
                infoRow("Homepage") {
                    Link(homepage.host() ?? homepage.absoluteString, destination: homepage)
                        .help(homepage.absoluteString)
                }
            }
            switch shown {
            case .formula(let formula): formulaRows(formula)
            case .cask(let cask): caskRows(cask)
            }
        }
    }

    @ViewBuilder
    private func formulaRows(_ formula: Formula) -> some View {
        if let license = formula.license {
            infoRow("License") { Text(license) }
        }
        if formula.isInstalled {
            if let installTime = formula.installTime {
                infoRow("Installed On") { Text(installTime, style: .date) }
            }
            infoRow("Installed By") {
                Text(formula.installedOnRequest ? "You" : "Another formula, as a dependency")
            }
        }
    }

    @ViewBuilder
    private func caskRows(_ cask: Cask) -> some View {
        infoRow("Auto Updates") {
            Text(cask.autoUpdates ? "Yes — the app updates itself" : "No")
        }
        if let appURL = cask.appURL {
            infoRow("App") {
                Text(appURL.path(percentEncoded: false))
                    .textSelection(.enabled)
            }
        }
    }

    private func infoRow(_ title: String, @ViewBuilder value: () -> some View) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            value()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Dependencies

    @ViewBuilder
    private func dependencySections(_ formula: Formula) -> some View {
        if !formula.dependencies.isEmpty {
            DependencyChips(title: "Dependencies", items: formula.dependencies.map { ($0, nil) }, select: showFormula)
        }
        let dependents = store.dependents(of: formula)
        if !dependents.isEmpty {
            DependencyChips(title: "Used By", items: dependents.map { ($0.name, nil) }, select: showFormula)
        }
        if !formula.runtimeDependencies.isEmpty {
            DependencyChips(
                title: "All Runtime Dependencies",
                items: formula.runtimeDependencies.map { ($0.fullName, $0.version) },
                startsExpanded: false,
                select: showFormula
            )
        }
    }

    /// The installed formula a chip names, selected on the Formulae page —
    /// or `nil` when it isn't installed.
    private func showFormula(named name: String) -> (() -> Void)? {
        guard let formula = store.formulae.first(where: { $0.name == name || $0.fullName == name }) else {
            return nil
        }
        return {
            store.formulaList.select(PackageID(kind: .formula, name: formula.name))
            sidebarSelection = SidebarItem.formulae.rawValue
        }
    }

    // MARK: - Data

    /// Search results past the first few have only a name; ask brew for the rest.
    private func fetchDetailsIfNeeded() async {
        guard package.isNameOnly else { return }
        switch package {
        case .formula(let formula):
            fetchedDetails = try? await Formula.info(named: [formula.name]).first.map(PackageType.formula)
        case .cask(let cask):
            fetchedDetails = try? await Cask.info(named: [cask.token]).first.map(PackageType.cask)
        }
    }
}

// MARK: - DependencyChips

/// Formula names as chips that open the formula; long lists fold away.
private struct DependencyChips: View {
    let title: String
    /// Name and optional version.
    let items: [(name: String, version: String?)]
    /// How the chip for a name opens it; `nil` for formulae not installed.
    let select: (String) -> (() -> Void)?

    @State private var isExpanded: Bool

    /// Lists longer than this start folded.
    private static let foldThreshold = 12

    init(
        title: String,
        items: [(name: String, version: String?)],
        startsExpanded: Bool = true,
        select: @escaping (String) -> (() -> Void)?
    ) {
        self.title = title
        self.items = items
        self.select = select
        _isExpanded = State(initialValue: startsExpanded && items.count <= Self.foldThreshold)
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            FlowLayout(spacing: Spacing.related) {
                ForEach(items, id: \.name) { item in
                    chip(item)
                }
            }
            .padding(.top, Spacing.item)
        } label: {
            Text("\(title) (\(items.count))")
                .font(.headline)
        }
    }

    @ViewBuilder
    private func chip(_ item: (name: String, version: String?)) -> some View {
        let label = HStack(spacing: Spacing.compact) {
            Text(item.name)
            if let version = item.version {
                Text(version)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout.monospaced())
        .chipInset()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.small))

        if let open = select(item.name) {
            Button(action: open) { label }
                .buttonStyle(.plain)
                .help("Show \(item.name)")
        } else {
            label
                .foregroundStyle(.secondary)
                .help("\(item.name) isn’t installed")
        }
    }
}

// MARK: - Preview

#Preview("Formula") {
    PackageDetailView(package: .formula(.preview))
        .environment(AppStores())
        .frame(width: 380, height: 700)
}

#Preview("Cask") {
    PackageDetailView(package: .cask(.preview))
        .environment(AppStores())
        .frame(width: 380, height: 700)
}

#Preview("Not Installed") {
    PackageDetailView(package: .formula(.stub(name: "wget")))
        .environment(AppStores())
        .frame(width: 380, height: 500)
}
