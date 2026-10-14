import SwiftUI
import UniformTypeIdentifiers
import CellarCore

/// Adds a project folder or a Mac setup Brewfile to the list. An existing
/// Brewfile is always used as it is.
struct AddBrewfileSheet: View {
    @State var kind: Brewfile.Kind

    @Environment(BrewfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var path: String?
    @State private var name = ""
    @State private var creation: BrewfileCreation = .empty
    @State private var isChoosingLocation = false

    private var fileExists: Bool {
        path.map { FileManager.default.fileExists(atPath: $0) } ?? false
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text("Add Brewfile")
                .font(.headline)

            Form {
                Picker("Kind", selection: $kind) {
                    Text("Project folder").tag(Brewfile.Kind.project)
                    Text("Mac setup").tag(Brewfile.Kind.mac)
                }
                .pickerStyle(.segmented)
                .onChange(of: kind) { path = nil }

                LabeledContent(kind == .project ? "Folder" : "Brewfile") {
                    HStack {
                        Text(path.map { ($0 as NSString).abbreviatingWithTildeInPath } ?? "None")
                            .foregroundStyle(path == nil ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Choose\u{2026}") { isChoosingLocation = true }
                    }
                }

                TextField("Name", text: $name, prompt: Text(kind == .project ? "My Web App" : "Work Setup"))

                contentsRow
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    guard let path else { return }
                    store.add(kind: kind, name: trimmedName, path: path, creation: creation)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(path == nil || trimmedName.isEmpty)
            }
        }
        .padding(Spacing.section)
        .frame(width: WindowSize.mediumSheet)
        .fileImporter(
            isPresented: $isChoosingLocation,
            allowedContentTypes: kind == .project ? [.folder] : [.folder, .item]
        ) { result in
            guard case .success(let url) = result else { return }
            choose(url)
        }
    }

    @ViewBuilder
    private var contentsRow: some View {
        if fileExists {
            LabeledContent("Contents") {
                Text("Use existing file — Cellar won’t change it")
                    .foregroundStyle(.secondary)
            }
        } else if kind == .mac {
            Picker("Contents", selection: $creation) {
                ForEach(BrewfileCreation.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.radioGroup)
        } else if path != nil {
            LabeledContent("Contents") {
                Text("Creates an empty Brewfile in the folder")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func choose(_ url: URL) {
        let brewfilePath = Brewfile.path(forFileOrFolder: url)
        path = brewfilePath
        if trimmedName.isEmpty {
            name = Brewfile.suggestedName(forPath: brewfilePath)
        }
    }
}

#Preview {
    AddBrewfileSheet(kind: .project)
        .environment(AppStores())
}
