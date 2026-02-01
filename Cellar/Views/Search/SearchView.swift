import SwiftUI
import CellarCore

struct SearchView: View {
    @State private var query = ""
    @State private var formulaResults: [Formula] = []
    @State private var caskResults: [Cask] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var errorMessage: String?
    @State private var installingPackages: Set<String> = []

    private var installedFormulae: [Formula] {
        formulaResults.filter(\.isInstalled)
    }

    private var availableFormulae: [Formula] {
        formulaResults.filter { !$0.isInstalled }
    }

    private var installedCasks: [Cask] {
        caskResults.filter(\.isInstalled)
    }

    private var availableCasks: [Cask] {
        caskResults.filter { !$0.isInstalled }
    }

    var body: some View {
        Group {
            if let errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await search() }
                }
            } else if isSearching {
                LoadingView(message: "Searching\u{2026}")
            } else if !hasSearched {
                promptView
            } else if formulaResults.isEmpty && caskResults.isEmpty {
                ContentUnavailableView {
                    Label("No Results", systemImage: "magnifyingglass")
                } description: {
                    Text("No packages found for \"\(query)\".")
                } actions: {
                    Text("Check the spelling or try a different search term.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                resultsList
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Search Homebrew packages")
        .onSubmit(of: .search) {
            Task { await search() }
        }
        .task(id: query) {
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await search()
        }
    }

    // MARK: - Prompt

    private var promptView: some View {
        ContentUnavailableView {
            Label("Search Homebrew", systemImage: "magnifyingglass")
                .font(.largeTitle)
        } description: {
            Text("Find formulae and casks to install from the Homebrew repository.")
        }
    }

    // MARK: - Results List

    private var resultsList: some View {
        List {
            if !installedFormulae.isEmpty {
                Section {
                    ForEach(installedFormulae) { formula in
                        SearchFormulaRow(
                            formula: formula,
                            isInstalling: installingPackages.contains(formula.name)
                        ) {
                            installFormula(formula)
                        }
                    }
                } header: {
                    CountedSectionHeader(title: "Installed Formulae", systemImage: "checkmark.circle.fill", count: installedFormulae.count)
                }
            }

            if !installedCasks.isEmpty {
                Section {
                    ForEach(installedCasks) { cask in
                        SearchCaskRow(
                            cask: cask,
                            isInstalling: installingPackages.contains(cask.token)
                        ) {
                            installCask(cask)
                        }
                    }
                } header: {
                    CountedSectionHeader(title: "Installed Casks", systemImage: "checkmark.circle.fill", count: installedCasks.count)
                }
            }

            if !availableFormulae.isEmpty {
                Section {
                    ForEach(availableFormulae) { formula in
                        SearchFormulaRow(
                            formula: formula,
                            isInstalling: installingPackages.contains(formula.name)
                        ) {
                            installFormula(formula)
                        }
                    }
                } header: {
                    CountedSectionHeader(title: "Available Formulae", systemImage: "arrow.down.circle", count: availableFormulae.count)
                }
            }

            if !availableCasks.isEmpty {
                Section {
                    ForEach(availableCasks) { cask in
                        SearchCaskRow(
                            cask: cask,
                            isInstalling: installingPackages.contains(cask.token)
                        ) {
                            installCask(cask)
                        }
                    }
                } header: {
                    CountedSectionHeader(title: "Available Casks", systemImage: "arrow.down.circle", count: availableCasks.count)
                }
            }
        }
    }

    // MARK: - Actions

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        hasSearched = true
        errorMessage = nil
        formulaResults = []
        caskResults = []

        do {
            async let formulae = Formula.search(for: trimmed)
            async let casks = Cask.search(for: trimmed)

            formulaResults = try await formulae
            caskResults = try await casks
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    private func installFormula(_ formula: Formula) {
        installingPackages.insert(formula.name)
        Task {
            do {
                let service = BrewService()
                for try await _ in service.install(formula.name, isCask: false) {}
            } catch {
                errorMessage = error.localizedDescription
            }
            installingPackages.remove(formula.name)
        }
    }

    private func installCask(_ cask: Cask) {
        installingPackages.insert(cask.token)
        Task {
            do {
                try await cask.install()
            } catch {
                errorMessage = error.localizedDescription
            }
            installingPackages.remove(cask.token)
        }
    }
}

// MARK: - Formula Row

private struct SearchFormulaRow: View {
    let formula: Formula
    let isInstalling: Bool
    let installAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(formula.name)
                    .fontWeight(.medium)

                if let desc = formula.desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if formula.isInstalled {
                StatusBadge(text: "Installed", color: .green)
            } else {
                Button {
                    installAction()
                } label: {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Install", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)
                .disabled(isInstalling)
            }
        }
        .padding(.vertical, Spacing.textPair)
    }
}

// MARK: - Cask Row

private struct SearchCaskRow: View {
    let cask: Cask
    let isInstalling: Bool
    let installAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(cask.displayName)
                    .fontWeight(.medium)

                if cask.displayName != cask.token {
                    Text(cask.token)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let desc = cask.desc {
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            if cask.isInstalled {
                StatusBadge(text: "Installed", color: .green)
            } else {
                Button {
                    installAction()
                } label: {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Install", systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)
                .disabled(isInstalling)
            }
        }
        .padding(.vertical, Spacing.textPair)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView()
    }
    .frame(width: 600, height: 500)
}
