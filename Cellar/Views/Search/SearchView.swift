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

    var body: some View {
        Group {
            if let errorMessage {
                ErrorView(message: errorMessage) {
                    search()
                }
            } else if isSearching {
                LoadingView(message: "Searching\u{2026}")
            } else if !hasSearched {
                promptView
            } else if formulaResults.isEmpty && caskResults.isEmpty {
                EmptyStateView(
                    title: "No Results",
                    systemImage: "magnifyingglass",
                    description: "No packages found for \"\(query)\"."
                )
            } else {
                resultsList
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Search Homebrew packages")
        .onSubmit(of: .search) {
            search()
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
            if !formulaResults.isEmpty {
                Section {
                    ForEach(formulaResults) { formula in
                        SearchFormulaRow(
                            formula: formula,
                            isInstalling: installingPackages.contains(formula.name)
                        ) {
                            installFormula(formula)
                        }
                    }
                } header: {
                    HStack {
                        Label("Formulae", systemImage: "terminal")
                        Spacer()
                        Text("\(formulaResults.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }

            if !caskResults.isEmpty {
                Section {
                    ForEach(caskResults) { cask in
                        SearchCaskRow(
                            cask: cask,
                            isInstalling: installingPackages.contains(cask.token)
                        ) {
                            installCask(cask)
                        }
                    }
                } header: {
                    HStack {
                        Label("Casks", systemImage: "macwindow")
                        Spacer()
                        Text("\(caskResults.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        hasSearched = true
        errorMessage = nil
        formulaResults = []
        caskResults = []

        Task {
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
            VStack(alignment: .leading, spacing: 2) {
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
                Text("Installed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.12), in: Capsule())
                    .foregroundStyle(.green)
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
        .padding(.vertical, 2)
    }
}

// MARK: - Cask Row

private struct SearchCaskRow: View {
    let cask: Cask
    let isInstalling: Bool
    let installAction: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
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
                Text("Installed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green.opacity(0.12), in: Capsule())
                    .foregroundStyle(.green)
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
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SearchView()
    }
    .frame(width: 600, height: 500)
}
