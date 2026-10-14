import SwiftUI
import CellarCore

/// A keyboard-first launcher: go to pages, open installed items, and run
/// commands such as Upgrade All or restarting a service.
struct QuickOpenView: View {
    @Binding var isPresented: Bool

    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(MaintenanceStore.self) private var maintenanceStore
    @Environment(ActivityStore.self) private var activityStore
    @Environment(\.openSettings) private var openSettings

    @State private var query = ""
    @State private var selectedIndex = 0
    /// Homebrew's matches for the query, installed or not.
    @State private var homebrewResults: [PackageType] = []
    @State private var isSearchingHomebrew = false
    @AppStorage(SettingsKey.quickOpenRecentItems) private var recentItemIDs = ""
    @FocusState private var isSearchFocused: Bool
    /// Where the pointer was when the keyboard last moved the selection;
    /// hover only takes over once the pointer actually moves.
    @State private var pointerAtKeyboardNavigation: CGPoint?

    /// Rows per kind of installed package or Homebrew result.
    private static let packageLimit = 8
    private static let homebrewLimit = 6

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [QuickOpenItem] {
        let trimmedQuery = trimmedQuery

        if trimmedQuery.isEmpty {
            let recent = recentItemIDs
                .split(separator: "|")
                .compactMap { resolveItem(id: String($0)) }
            let pinned = packageStore.formulae
                .filter(\.pinned)
                .prefix(6)
                .map { QuickOpenItem.package(.formula($0)) }
            let destinations = SidebarItem.allCases.map(QuickOpenItem.destination)
            return deduplicated(recent + pinned + destinations)
        }

        let commands = commands(matching: trimmedQuery).map(QuickOpenItem.command)

        let destinations = SidebarItem.allCases
            .filter { $0.matches(trimmedQuery) }
            .map(QuickOpenItem.destination)

        let packages = PackageKind.allCases.flatMap { kind in
            packageStore.packages(kind)
                .filter { $0.matches(trimmedQuery) }
                .sorted { matchRank($0.name, query: trimmedQuery) < matchRank($1.name, query: trimmedQuery) }
                .prefix(Self.packageLimit)
                .map(QuickOpenItem.package)
        }

        let services = serviceStore.services
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { matchRank($0.name, query: trimmedQuery) < matchRank($1.name, query: trimmedQuery) }
            .prefix(6)
            .map(QuickOpenItem.service)

        let available = PackageKind.allCases.flatMap { kind in
            homebrewResults
                .filter { $0.kind == kind && packageStore.package($0.id) == nil }
                .prefix(Self.homebrewLimit)
                .map(QuickOpenItem.available)
        }

        return commands + destinations + packages + services + available
    }

    // MARK: - Commands

    private func commands(matching query: String) -> [QuickOpenCommand] {
        let general = [
            QuickOpenCommand(
                title: "Upgrade All\u{2026}",
                keywords: ["upgrade", "update all"],
                systemImage: "arrow.up.circle",
                isEnabled: packageStore.canUpgradeAll
            ) { packageStore.isUpgradePreviewPresented = true },
            QuickOpenCommand(
                title: "Check for Package Updates",
                keywords: ["brew update", "check", "refresh"],
                systemImage: "arrow.triangle.2.circlepath",
                isEnabled: !activityStore.isActive(.homebrew)
            ) { Task { await packageStore.checkForUpdates() } },
            QuickOpenCommand(
                title: "Clean Up\u{2026}",
                keywords: ["cleanup", "disk space", "free"],
                systemImage: "trash.circle",
                isEnabled: !maintenanceStore.isRunning
            ) { maintenanceStore.isCleanupPreviewPresented = true },
            QuickOpenCommand(
                title: "Run Health Check",
                keywords: ["doctor", "health"],
                systemImage: "stethoscope",
                isEnabled: !maintenanceStore.isRunning
            ) { Task { await maintenanceStore.runHealthCheck() } },
            QuickOpenCommand(title: "Show Activity", keywords: ["log", "progress"], systemImage: "clock") {
                ActivityPanel.show()
            },
            QuickOpenCommand(title: "Settings\u{2026}", keywords: ["preferences"], systemImage: "gear") {
                openSettings()
            },
        ]
        return (general + serviceCommands(matching: query))
            .filter { $0.isEnabled && $0.matches(query) }
    }

    /// The basic actions of services whose name matches the query.
    private func serviceCommands(matching query: String) -> [QuickOpenCommand] {
        serviceStore.services
            .filter { query.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(query) }
            .prefix(3)
            .flatMap { service in
                ServiceAction.basic
                    .filter { $0.isAvailable(for: service) }
                    .map { action in
                        QuickOpenCommand(
                            title: "\(action.title(for: service)) \(service.name)",
                            systemImage: action.systemImage,
                            isEnabled: !serviceStore.isBusy(service)
                        ) {
                            Task { await action.perform(on: service, store: serviceStore) }
                        }
                    }
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
            Divider()
            keyboardHints
        }
        .onAppear { isSearchFocused = true }
        .onChange(of: query) { selectedIndex = 0 }
        .task(id: query) { await searchHomebrew() }
        .onExitCommand { isPresented = false }
        .onKeyPress(.downArrow) {
            moveSelection(by: 1)
            return .handled
        }
        .onKeyPress(.upArrow) {
            moveSelection(by: -1)
            return .handled
        }
        .accessibilityAddTraits(.isModal)
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)

            TextField("Search pages, packages, services and commands", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                .focused($isSearchFocused)
                .onSubmit { openSelectedResult() }

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, Spacing.cardPadding)
        .frame(height: 58)
    }

    @ViewBuilder
    private var resultsList: some View {
        if results.isEmpty {
            ContentUnavailableView.search(text: query)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Spacing.compact) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                            resultRow(result, at: index)
                                .id(result.id)
                        }
                    }
                    .padding(Spacing.item)
                }
                .onChange(of: selectedIndex) {
                    guard results.indices.contains(selectedIndex) else { return }
                    withAnimation(AnimationToken.gentle) {
                        proxy.scrollTo(results[selectedIndex].id, anchor: .center)
                    }
                }
            }
        }
    }

    private func resultRow(_ result: QuickOpenItem, at index: Int) -> some View {
        Button {
            open(result)
        } label: {
            HStack(spacing: Spacing.sectionContent) {
                Image(systemName: result.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(result.color)
                    .frame(width: IconSize.smallIcon, height: IconSize.smallIcon)
                    .background(result.color.opacity(Opacity.iconBackground), in: RoundedRectangle(cornerRadius: CornerRadius.small))

                VStack(alignment: .leading, spacing: Spacing.textPair) {
                    Text(result.title)
                        .font(.body.weight(.medium))
                        .lineLimit(1)

                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(result.category)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if index == selectedIndex {
                    Image(systemName: "return")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.item)
            .padding(.vertical, Spacing.related)
            .contentShape(Rectangle())
            .background(
                index == selectedIndex ? Color.accentColor.opacity(Opacity.badgeBackground) : .clear,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            guard isHovered, pointerHasMoved else { return }
            selectedIndex = index
        }
        .accessibilityHint(result.isCommand ? "Runs the command" : "Opens the \(result.category.lowercased())")
    }

    private var keyboardHints: some View {
        HStack(spacing: Spacing.sectionContent) {
            if isSearchingHomebrew {
                ProgressView()
                    .controlSize(.small)
                Text("Searching Homebrew…")
                    .foregroundStyle(.secondary)
            } else {
                Text(query.isEmpty ? "Recent, pinned, and destinations" : "\(results.count) results")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            keyHint("↑↓", label: "Navigate")
            keyHint("↩", label: "Open")
            keyHint("esc", label: "Close")
        }
        .font(.caption)
        .padding(.horizontal, Spacing.cardPadding)
        .frame(height: 42)
    }

    private func keyHint(_ key: String, label: String) -> some View {
        HStack(spacing: Spacing.compact) {
            Text(key)
                .font(.caption.monospaced().weight(.medium))
                .padding(.horizontal, Spacing.compact)
                .padding(.vertical, Spacing.textPair)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: CornerRadius.minimal))
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func moveSelection(by offset: Int) {
        guard !results.isEmpty else { return }
        pointerAtKeyboardNavigation = NSEvent.mouseLocation
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    /// Scrolling moves rows under a still pointer; that must not count as hover.
    private var pointerHasMoved: Bool {
        guard let pointerAtKeyboardNavigation else { return true }
        return NSEvent.mouseLocation != pointerAtKeyboardNavigation
    }

    private func openSelectedResult() {
        guard results.indices.contains(selectedIndex) else { return }
        open(results[selectedIndex])
    }

    private func open(_ result: QuickOpenItem) {
        switch result.kind {
        case .destination(let item):
            Navigator.show(item)
        case .package(let package):
            Navigator.show(package.id, in: packageStore)
        case .service(let service):
            Navigator.show(service: service.name, in: serviceStore)
        case .available(let package):
            Navigator.search(for: package.id, in: packageStore)
        case .command(let command):
            isPresented = false
            command.perform()
            return
        }
        remember(result)
        isPresented = false
    }

    private func searchHomebrew() async {
        let value = trimmedQuery
        guard value.count >= PackageStore.minimumSearchLength else {
            homebrewResults = []
            isSearchingHomebrew = false
            return
        }

        try? await Task.sleep(for: PackageStore.searchDelay)
        guard !Task.isCancelled else { return }
        isSearchingHomebrew = true
        defer { isSearchingHomebrew = false }

        async let formulae = PackageStore.searchHomebrew(value, kind: .formula, detailLimit: Self.homebrewLimit)
        async let casks = PackageStore.searchHomebrew(value, kind: .cask, detailLimit: Self.homebrewLimit)
        let found = (try? await formulae + casks) ?? []
        guard !Task.isCancelled else { return }
        homebrewResults = found
    }

    private func remember(_ item: QuickOpenItem) {
        var ids = recentItemIDs.split(separator: "|").map(String.init)
        ids.removeAll { $0 == item.id }
        ids.insert(item.id, at: 0)
        recentItemIDs = ids.prefix(8).joined(separator: "|")
    }

    /// A remembered item, if it still exists.
    private func resolveItem(id: String) -> QuickOpenItem? {
        if let packageID = PackageID(rawValue: id) {
            return packageStore.package(packageID).map(QuickOpenItem.package)
        }
        let others = SidebarItem.allCases.map(QuickOpenItem.destination)
            + serviceStore.services.map(QuickOpenItem.service)
        return others.first { $0.id == id }
    }

    private func deduplicated(_ items: [QuickOpenItem]) -> [QuickOpenItem] {
        var seen: Set<String> = []
        return items.filter { seen.insert($0.id).inserted }
    }

    private func matchRank(_ value: String, query: String) -> Int {
        value.localizedCaseInsensitiveCompare(query) == .orderedSame ? 0
            : value.localizedLowercase.hasPrefix(query.localizedLowercase) ? 1 : 2
    }
}

private struct QuickOpenItem: Identifiable {
    enum Kind {
        case destination(SidebarItem)
        /// An installed formula or cask.
        case package(PackageType)
        case service(BrewServiceItem)
        /// A package Homebrew offers that isn't installed.
        case available(PackageType)
        case command(QuickOpenCommand)
    }

    let kind: Kind

    var isCommand: Bool {
        if case .command = kind { return true }
        return false
    }

    static func destination(_ item: SidebarItem) -> Self { .init(kind: .destination(item)) }
    static func package(_ package: PackageType) -> Self { .init(kind: .package(package)) }
    static func service(_ service: BrewServiceItem) -> Self { .init(kind: .service(service)) }
    static func available(_ package: PackageType) -> Self { .init(kind: .available(package)) }
    static func command(_ command: QuickOpenCommand) -> Self { .init(kind: .command(command)) }

    /// Recent items are remembered by this; packages by `PackageID.rawValue`.
    var id: String {
        switch kind {
        case .destination(let item): "destination:\(item.id)"
        case .package(let package): package.id.rawValue
        case .service(let service): "service:\(service.id)"
        case .available(let package): "available-\(package.id.rawValue)"
        case .command(let command): "command:\(command.title)"
        }
    }

    var title: String {
        switch kind {
        case .destination(let item): item.title
        case .package(let package), .available(let package): package.name
        case .service(let service): service.name
        case .command(let command): command.title
        }
    }

    var subtitle: String {
        switch kind {
        case .destination(let item): item.section.title ?? "Overview"
        case .package(let package): package.description ?? "Version \(package.version)"
        case .service(let service): service.status.label
        case .available(let package): package.description ?? "Available from Homebrew"
        case .command: "Command"
        }
    }

    var category: String {
        switch kind {
        case .destination: String(localized: "Destination")
        case .package(let package): package.kind == .formula ? String(localized: "Formula") : String(localized: "Cask")
        case .service: String(localized: "Service")
        case .available(let package):
            package.kind == .formula ? String(localized: "Available Formula") : String(localized: "Available Cask")
        case .command: String(localized: "Command")
        }
    }

    var systemImage: String {
        switch kind {
        case .destination(let item): item.icon
        case .package(let package): package.kind.systemImage
        case .service: SidebarItem.services.icon
        case .available: "arrow.down.circle"
        case .command(let command): command.systemImage
        }
    }

    var color: Color {
        switch kind {
        case .destination: .accentColor
        case .package(let package), .available(let package): package.kind.color
        case .service(let service): service.status.color
        case .command: .orange
        }
    }
}

/// An action Quick Open can run directly.
private struct QuickOpenCommand {
    let title: String
    var keywords: [String] = []
    let systemImage: String
    var isEnabled = true
    let perform: () -> Void

    func matches(_ query: String) -> Bool {
        title.localizedCaseInsensitiveContains(query)
            || keywords.contains { $0.localizedCaseInsensitiveContains(query) || query.localizedCaseInsensitiveContains($0) }
    }
}

#Preview {
    @Previewable @State var isPresented = true

    QuickOpenView(isPresented: $isPresented)
        .environment(AppStores())
}
