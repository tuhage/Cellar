import SwiftUI
import CellarCore

/// Edits a Brewfile's text. Closing with unsaved changes asks first.
struct BrewfileEditorSheet: View {
    let brewfile: Brewfile

    @Environment(BrewfileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String
    @State private var isConfirmingDiscard = false
    private let original: String

    init(brewfile: Brewfile, text: String) {
        self.brewfile = brewfile
        original = text
        _draft = State(initialValue: text)
    }

    private var hasChanges: Bool { draft != original }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.textPair) {
                    Text("Edit \(brewfile.name)")
                        .font(.headline)
                    Text(brewfile.displayPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    brewfile.openInExternalEditor()
                } label: {
                    Label("Open in External Editor", systemImage: "arrow.up.forward.app")
                }
                .help("Edit in your default text editor; Cellar reloads the file when you come back")
            }
            .padding(Spacing.cardPadding)

            Divider()

            PlainTextEditor(text: $draft)

            Divider()

            HStack {
                Text("\(draft.split(separator: "\n", omittingEmptySubsequences: false).count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", role: .cancel) {
                    if hasChanges { isConfirmingDiscard = true } else { dismiss() }
                }
                .keyboardShortcut(.cancelAction)
                Button("Save") {
                    Task { await store.save(draft, to: brewfile) }
                    dismiss()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasChanges)
            }
            .padding(Spacing.sectionContent)
        }
        .frame(minWidth: WindowSize.fullDetailWidth, minHeight: WindowSize.mediumSheetHeight)
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog("Discard your changes?", isPresented: $isConfirmingDiscard) {
            Button("Discard Changes", role: .destructive) { dismiss() }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your edits to \(brewfile.displayPath) haven’t been saved.")
        }
    }
}

#Preview {
    BrewfileEditorSheet(brewfile: .preview, text: "brew \"wget\"\ncask \"firefox\"\n")
        .environment(AppStores())
}
