import SwiftUI

/// Open and Reveal in Finder buttons for a file, disabled while it's
/// missing.
struct FileActions: View {
    let path: String
    var openTitle = "Open"

    private var url: URL { URL(fileURLWithPath: path) }

    var body: some View {
        HStack(spacing: Spacing.item) {
            Button(openTitle) {
                NSWorkspace.shared.open(url)
            }
            .help("Open \(url.lastPathComponent) in its default app")

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "folder")
            }
            .help("Reveal in Finder")
            .accessibilityLabel("Reveal in Finder")
        }
        .controlSize(.small)
        .disabled(!FileManager.default.fileExists(atPath: path))
    }
}

#Preview {
    FileActions(path: "/etc/hosts", openTitle: "Open Log")
        .padding()
}
