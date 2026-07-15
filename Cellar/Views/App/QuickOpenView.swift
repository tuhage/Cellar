import SwiftUI
import CellarCore

/// A keyboard-first launcher for navigating Cellar and opening installed items.
struct QuickOpenView: View {
    @Binding var selection: SidebarItem?
    @Binding var isPresented: Bool

    @Environment(PackageStore.self) private var packageStore
    @Environment(ServiceStore.self) private var serviceStore

    @State private var query = ""
    @State private var selectedIndex = 0
    @State private var availableFormulae: [Formula] = []
    @State private var availableCasks: [Cask] = []
    @State private var isSearchingHomebrew = false
    @AppStorage("quickOpenRecentItems") private var recentItemIDs = ""
    @FocusState private var isSearchFocused: Bool

    private var results: [QuickOpenItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedQuery.isEmpty {
            let recent = recentItemIDs
                .split(separator: "|")
                .compactMap { resolveItem(id: String($0)) }
            let pinned = packageStore.formulae
                .filter(\.pinned)
                .prefix(6)
                .map(QuickOpenItem.formula)
            let destinations = SidebarItem.allCases.map(QuickOpenItem.destination)
            return deduplicated(recent + pinned + destinations)
        }

        let destinations = SidebarItem.allCases
            .filter { $0.title.localizedCaseInsensitiveContains(trimmedQuery) }
            .map(QuickOpenItem.destination)

        let formulae = packageStore.formulae
            .filter {
                $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                    || ($0.desc?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
            .sorted { matchRank($0.name, query: trimmedQuery) < matchRank($1.name, query: trimmedQuery) }
            .prefix(8)
            .map(QuickOpenItem.formula)

        let casks = packageStore.casks
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.token.localizedCaseInsensitiveContains(trimmedQuery)
                    || ($0.desc?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
            .sorted { matchRank($0.displayName, query: trimmedQuery) < matchRank($1.displayName, query: trimmedQuery) }
            .prefix(8)
            .map(QuickOpenItem.cask)

        let services = serviceStore.services
            .filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
            .sorted { matchRank($0.name, query: trimmedQuery) < matchRank($1.name, query: trimmedQuery) }
            .prefix(6)
            .map(QuickOpenItem.service)

        let installedFormulaNames = Set(packageStore.formulae.map(\.name))
        let remoteFormulae = availableFormulae
            .filter { !installedFormulaNames.contains($0.name) }
            .prefix(6)
            .map(QuickOpenItem.availableFormula)

        let installedCaskTokens = Set(packageStore.casks.map(\.token))
        let remoteCasks = availableCasks
            .filter { !installedCaskTokens.contains($0.token) }
            .prefix(6)
            .map(QuickOpenItem.availableCask)

        return destinations + formulae + casks + services + remoteFormulae + remoteCasks
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            resultsList
            Divider()
            keyboardHints
        }
        .frame(width: 580, height: 520)
        .background(.background)
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
    }

    private var searchField: some View {
        HStack(spacing: Spacing.sectionContent) {
            Image(systemName: "magnifyingglass")
                .font(.title3)
                .foregroundStyle(.secondary)

            TextField("Search destinations, packages, and services", text: $query)
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
                index == selectedIndex ? Color.accentColor.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered in
            if isHovered { selectedIndex = index }
        }
        .accessibilityHint("Open \(result.category.lowercased())")
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
        selectedIndex = min(max(selectedIndex + offset, 0), results.count - 1)
    }

    private func openSelectedResult() {
        guard results.indices.contains(selectedIndex) else { return }
        open(results[selectedIndex])
    }

    private func open(_ result: QuickOpenItem) {
        switch result.kind {
        case .destination(let item):
            selection = item
        case .formula(let formula):
            packageStore.selectedFormulaId = formula.id
            selection = .formulae
        case .cask(let cask):
            packageStore.selectedCaskId = cask.id
            selection = .casks
        case .service(let service):
            serviceStore.selectedServiceId = service.id
            selection = .services
        case .availableFormula(let formula):
            packageStore.formulaSearchQuery = formula.name
            selection = .formulae
        case .availableCask(let cask):
            packageStore.caskSearchQuery = cask.token
            selection = .casks
        }
        remember(result)
        isPresented = false
    }

    private func searchHomebrew() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2 else {
            availableFormulae = []
            availableCasks = []
            isSearchingHomebrew = false
            return
        }

        try? await Task.sleep(for: .milliseconds(400))
        guard !Task.isCancelled else { return }
        isSearchingHomebrew = true
        defer { isSearchingHomebrew = false }

        do {
            async let formulae = Formula.search(for: value)
            async let casks = Cask.search(for: value)
            let loaded = try await (formulae, casks)
            guard !Task.isCancelled,
                  query.trimmingCharacters(in: .whitespacesAndNewlines) == value else { return }
            availableFormulae = loaded.0
            availableCasks = loaded.1
        } catch {
            guard !Task.isCancelled else { return }
            availableFormulae = []
            availableCasks = []
        }
    }

    private func remember(_ item: QuickOpenItem) {
        var ids = recentItemIDs.split(separator: "|").map(String.init)
        ids.removeAll { $0 == item.id }
        ids.insert(item.id, at: 0)
        recentItemIDs = ids.prefix(8).joined(separator: "|")
    }

    private func resolveItem(id: String) -> QuickOpenItem? {
        let parts = id.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "destination":
            return SidebarItem(rawValue: parts[1]).map(QuickOpenItem.destination)
        case "formula":
            return packageStore.formulae.first { $0.id == parts[1] }.map(QuickOpenItem.formula)
        case "cask":
            return packageStore.casks.first { $0.id == parts[1] }.map(QuickOpenItem.cask)
        case "service":
            return serviceStore.services.first { $0.id == parts[1] }.map(QuickOpenItem.service)
        default:
            return nil
        }
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
        case formula(Formula)
        case cask(Cask)
        case service(BrewServiceItem)
        case availableFormula(Formula)
        case availableCask(Cask)
    }

    let kind: Kind

    static func destination(_ item: SidebarItem) -> Self { .init(kind: .destination(item)) }
    static func formula(_ formula: Formula) -> Self { .init(kind: .formula(formula)) }
    static func cask(_ cask: Cask) -> Self { .init(kind: .cask(cask)) }
    static func service(_ service: BrewServiceItem) -> Self { .init(kind: .service(service)) }
    static func availableFormula(_ formula: Formula) -> Self { .init(kind: .availableFormula(formula)) }
    static func availableCask(_ cask: Cask) -> Self { .init(kind: .availableCask(cask)) }

    var id: String {
        switch kind {
        case .destination(let item): "destination:\(item.id)"
        case .formula(let formula): "formula:\(formula.id)"
        case .cask(let cask): "cask:\(cask.id)"
        case .service(let service): "service:\(service.id)"
        case .availableFormula(let formula): "available-formula:\(formula.id)"
        case .availableCask(let cask): "available-cask:\(cask.id)"
        }
    }

    var title: String {
        switch kind {
        case .destination(let item): item.title
        case .formula(let formula): formula.name
        case .cask(let cask): cask.displayName
        case .service(let service): service.name
        case .availableFormula(let formula): formula.name
        case .availableCask(let cask): cask.token
        }
    }

    var subtitle: String {
        switch kind {
        case .destination(let item): item.section.title
        case .formula(let formula): formula.desc ?? "Version \(formula.version)"
        case .cask(let cask): cask.desc ?? cask.token
        case .service(let service): service.status.label
        case .availableFormula: "Available from Homebrew"
        case .availableCask: "Available from Homebrew"
        }
    }

    var category: String {
        switch kind {
        case .destination: String(localized: "Destination")
        case .formula: String(localized: "Formula")
        case .cask: String(localized: "Cask")
        case .service: String(localized: "Service")
        case .availableFormula: String(localized: "Available Formula")
        case .availableCask: String(localized: "Available Cask")
        }
    }

    var systemImage: String {
        switch kind {
        case .destination(let item): item.icon
        case .formula: "terminal"
        case .cask: "macwindow"
        case .service: "gearshape.2"
        case .availableFormula: "arrow.down.circle"
        case .availableCask: "arrow.down.circle"
        }
    }

    var color: Color {
        switch kind {
        case .destination: .accentColor
        case .formula: .blue
        case .cask: .purple
        case .service(let service): service.status.color
        case .availableFormula: .blue
        case .availableCask: .purple
        }
    }
}

#Preview {
    @Previewable @State var selection: SidebarItem? = .dashboard
    @Previewable @State var isPresented = true

    QuickOpenView(selection: $selection, isPresented: $isPresented)
        .environment(PackageStore())
        .environment(ServiceStore())
}
