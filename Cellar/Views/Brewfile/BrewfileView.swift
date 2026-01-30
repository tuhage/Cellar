import SwiftUI
import CellarCore

// MARK: - BrewfileView

/// Main Brewfile management view with a profile list on the left
/// and a Brewfile content editor on the right.
struct BrewfileView: View {
    @Environment(BrewfileStore.self) private var store

    @State private var isAddingProfile = false
    @State private var newProfileName = ""
    @State private var newProfilePath = ""
    @State private var showingImportOutput = false

    var body: some View {
        @Bindable var store = store

        Group {
            if store.isImporting, let stream = store.importStream {
                importOutputView(stream: stream)
            } else {
                mainContent
            }
        }
        .navigationTitle("Brewfile")
        .toolbar { toolbarContent }
        .sheet(isPresented: $isAddingProfile) { addProfileSheet }
        .task { store.loadProfiles() }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        HSplitView {
            profileList
                .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
            editorPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Profile List

    private var profileList: some View {
        @Bindable var store = store

        return VStack(spacing: 0) {
            List(selection: $store.selectedProfileId) {
                ForEach(store.profiles) { profile in
                    profileRow(profile)
                        .tag(profile.id)
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteProfile(profile)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: store.selectedProfileId) { _, newValue in
                if let newValue,
                   let profile = store.profiles.first(where: { $0.id == newValue }) {
                    store.loadBrewfileContent(for: profile)
                }
            }

            Divider()

            HStack {
                Button {
                    newProfileName = ""
                    newProfilePath = defaultBrewfilePath()
                    isAddingProfile = true
                } label: {
                    Label("Add Profile", systemImage: "plus")
                }
                .buttonStyle(.borderless)

                Spacer()

                if let profile = store.selectedProfile {
                    Button(role: .destructive) {
                        store.deleteProfile(profile)
                    } label: {
                        Label("Delete", systemImage: "minus")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
        }
    }

    private func profileRow(_ profile: BrewfileProfile) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profile.name)
                .fontWeight(.medium)
            if let lastExported = profile.lastExported {
                Text("Exported \(lastExported, format: .relative(presentation: .named))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Never exported")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Editor Panel

    @ViewBuilder
    private var editorPanel: some View {
        if let profile = store.selectedProfile {
            editorContent(for: profile)
        } else {
            emptySelection
        }
    }

    private func editorContent(for profile: BrewfileProfile) -> some View {
        @Bindable var store = store

        return VStack(spacing: 0) {
            editorHeader(for: profile)
            Divider()
            TextEditor(text: $store.brewfileContent)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)

            Divider()
            editorFooter(for: profile)
        }
    }

    private func editorHeader(for profile: BrewfileProfile) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.headline)
                Text(profile.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding()
    }

    private func editorFooter(for profile: BrewfileProfile) -> some View {
        HStack {
            let lineCount = store.brewfileContent.components(separatedBy: "\n").count
            Text("\(lineCount) lines")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.fill.tertiary, in: Capsule())

            Spacer()

            Button("Save") {
                store.saveBrewfileContent(for: profile)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(8)
    }

    private var emptySelection: some View {
        ContentUnavailableView(
            "Select a Profile",
            systemImage: "doc.text",
            description: Text("Choose a Brewfile profile from the list or create a new one.")
        )
    }

    // MARK: - Import Output

    private func importOutputView(stream: AsyncThrowingStream<String, Error>) -> some View {
        VStack(spacing: 0) {
            ProcessOutputView(
                title: "Installing from Brewfile",
                stream: stream
            )

            Divider()

            HStack {
                Spacer()
                Button("Done") {
                    store.endImport()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding()
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                guard let profile = store.selectedProfile else { return }
                Task { await store.exportBrewfile(to: profile) }
            } label: {
                Label("Export Current", systemImage: "square.and.arrow.up")
            }
            .disabled(store.selectedProfile == nil || store.isLoading)
            .help("Export current Homebrew packages to this Brewfile")

            Button {
                guard let profile = store.selectedProfile else { return }
                store.beginImport(from: profile)
            } label: {
                Label("Import / Install", systemImage: "square.and.arrow.down")
            }
            .disabled(store.selectedProfile == nil || store.isLoading || store.isImporting)
            .help("Install all packages from this Brewfile")
        }
    }

    // MARK: - Add Profile Sheet

    private var addProfileSheet: some View {
        VStack(spacing: 16) {
            Text("New Brewfile Profile")
                .font(.headline)

            Form {
                TextField("Name", text: $newProfileName)
                TextField("File Path", text: $newProfilePath)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    isAddingProfile = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Create") {
                    let name = newProfileName.trimmingCharacters(in: .whitespaces)
                    let path = newProfilePath.trimmingCharacters(in: .whitespaces)
                    guard !name.isEmpty, !path.isEmpty else { return }
                    store.createProfile(name: name, path: path)
                    isAddingProfile = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    newProfileName.trimmingCharacters(in: .whitespaces).isEmpty
                    || newProfilePath.trimmingCharacters(in: .whitespaces).isEmpty
                )
            }
        }
        .padding()
        .frame(width: 420)
    }

    // MARK: - Helpers

    private func defaultBrewfilePath() -> String {
        "\(NSHomeDirectory())/Brewfile"
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        BrewfileView()
            .environment(BrewfileStore())
    }
    .frame(width: 800, height: 600)
}
