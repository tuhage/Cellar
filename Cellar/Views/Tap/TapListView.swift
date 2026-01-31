import SwiftUI
import CellarCore

struct TapListView: View {
    @Environment(TapStore.self) private var store

    @State private var selectedTapID: Tap.ID?
    @State private var showingAddSheet = false
    @State private var sortOrder: [KeyPathComparator<Tap>] = [
        KeyPathComparator(\.name)
    ]

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.taps.isEmpty {
                LoadingView(message: "Loading taps\u{2026}")
            } else if let errorMessage = store.errorMessage, store.taps.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await store.load() }
                }
            } else if store.taps.isEmpty {
                EmptyStateView(
                    title: "No Taps",
                    systemImage: "spigot",
                    description: "No Homebrew taps are installed."
                )
            } else {
                tapTable
            }
        }
        .overlay {
            if let stream = store.actionStream {
                ProcessOutputView(title: "Adding Tap", stream: stream)
                    .background(.background)
                    .onDisappear {
                        store.dismissAction()
                        Task { await store.load() }
                    }
            }
        }
        .navigationTitle("Taps")
        .searchable(text: $store.searchQuery, prompt: "Filter taps")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Tap", systemImage: "plus")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }

            ToolbarItem(placement: .status) {
                if !store.taps.isEmpty {
                    Text("\(store.taps.count) taps")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            if store.taps.isEmpty {
                await store.load()
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTapSheet(store: store)
        }
    }

    // MARK: - Table

    private var tapTable: some View {
        Table(store.filteredTaps, selection: $selectedTapID, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { tap in
                HStack(spacing: 6) {
                    Text(tap.name)
                        .fontWeight(.medium)
                    if tap.official {
                        Text("Official")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.blue.opacity(0.1), in: Capsule())
                    }
                }
            }
            .width(min: 140, ideal: 220)

            TableColumn("Formulae") { tap in
                Text("\(tap.formulaCount)")
                    .foregroundStyle(tap.formulaCount > 0 ? .primary : .quaternary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Casks") { tap in
                Text("\(tap.caskCount)")
                    .foregroundStyle(tap.caskCount > 0 ? .primary : .quaternary)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Source") { tap in
                HStack(spacing: 6) {
                    Image(systemName: tap.installed ? "externaldrive" : "cloud")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Text(tap.installed ? "Local" : "API")
                        .font(.callout)
                }
            }
            .width(min: 70, ideal: 90)

            TableColumn("Last Commit") { tap in
                Text(tap.lastCommit.isEmpty ? "--" : tap.lastCommit)
                    .foregroundStyle(tap.lastCommit.isEmpty ? .quaternary : .secondary)
            }
            .width(min: 80, ideal: 120)
        }
        .contextMenu(forSelectionType: Tap.ID.self) { selectedIDs in
            if let id = selectedIDs.first,
               let tap = store.taps.first(where: { $0.id == id }) {
                tapContextMenu(for: tap)
            }
        } primaryAction: { _ in }
        .onChange(of: sortOrder) { _, newOrder in
            store.taps.sort(using: newOrder)
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func tapContextMenu(for tap: Tap) -> some View {
        if let url = tap.githubURL {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open on GitHub", systemImage: "arrow.up.right.square")
            }
        }

        Divider()

        Button(role: .destructive) {
            Task { await store.removeTap(tap) }
        } label: {
            Label("Untap", systemImage: "trash")
        }
    }
}

// MARK: - Add Tap Sheet

private struct AddTapSheet: View {
    let store: TapStore

    @Environment(\.dismiss) private var dismiss
    @State private var tapName = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Tap")
                .font(.headline)

            TextField("user/repo", text: $tapName)
                .textFieldStyle(.roundedBorder)

            Text("Enter a tap name in the format user/repo (e.g. homebrew/cask-fonts).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Add Tap") {
                    store.addTap(tapName)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(tapName.isEmpty || !tapName.contains("/"))
            }
        }
        .padding()
        .frame(width: 360)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TapListView()
            .environment(TapStore())
    }
    .frame(width: 700, height: 500)
}
