import SwiftUI
import CellarCore

/// The end of a service's error log, so a failure's cause is visible
/// without leaving Cellar.
struct ServiceLogSection: View {
    let service: BrewServiceItem
    let info: ServiceInfo

    /// `nil` while loading or when the log can't be read.
    @State private var lines: [String]?
    @State private var hasLoaded = false

    private static let lineCount = 20

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            HStack {
                Text("Logs")
                    .font(.headline)
                Spacer()
                if let path = info.errorLogOrLogPath {
                    FileActions(path: path, openTitle: "Open Log")
                }
            }

            logContent
        }
        // Re-read when the service changes state, e.g. after it failed.
        .task(id: service) {
            lines = await info.recentErrorLines(Self.lineCount)
            hasLoaded = true
        }
    }

    @ViewBuilder
    private var logContent: some View {
        if info.errorLogOrLogPath == nil {
            Text("This service doesn’t write a log.")
                .foregroundStyle(.secondary)
        } else if let lines, !lines.isEmpty {
            ScrollView(.horizontal) {
                Text(lines.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .fixedSize()
                    .padding(Spacing.sectionContent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(cornerRadius: CornerRadius.medium)
        } else if hasLoaded {
            Text(lines == nil
                 ? "The log can’t be read. Root services often write logs only root can read."
                 : "The log is empty.")
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - File Actions

/// Open and Reveal in Finder buttons for a file path.
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

// MARK: - Preview

#Preview {
    ServiceLogSection(service: .preview, info: .preview)
        .padding()
        .frame(width: 420)
}
