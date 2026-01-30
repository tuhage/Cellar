import SwiftUI
import CellarCore
import UniformTypeIdentifiers

// MARK: - ComparisonView

/// Compares two Brewfiles side-by-side and shows differences.
/// Users provide paths to two Brewfile files, then click Compare to see
/// categorized results: only in source, only in target, and shared packages.
struct ComparisonView: View {
    @State private var sourcePath = ""
    @State private var targetPath = ""
    @State private var result: CellarCore.ComparisonResult?
    @State private var errorMessage: String?
    @State private var isExporting = false

    var body: some View {
        VStack(spacing: 0) {
            inputPanel
            Divider()
            resultPanel
        }
        .navigationTitle("Comparison")
        .toolbar { toolbarContent }
        .fileExporter(
            isPresented: $isExporting,
            document: diffDocument,
            contentType: .plainText,
            defaultFilename: "brewfile-diff.txt"
        ) { exportResult in
            if case .failure(let error) = exportResult {
                errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Input Panel

    private var inputPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source Brewfile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Path to source Brewfile", text: $sourcePath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            if let path = browseForFile() {
                                sourcePath = path
                            }
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Brewfile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("Path to target Brewfile", text: $targetPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") {
                            if let path = browseForFile() {
                                targetPath = path
                            }
                        }
                        .controlSize(.small)
                    }
                }
            }

            HStack {
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Spacer()

                Button("Compare") {
                    performComparison()
                }
                .buttonStyle(.borderedProminent)
                .disabled(sourcePath.trimmingCharacters(in: .whitespaces).isEmpty
                          || targetPath.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
    }

    // MARK: - Result Panel

    @ViewBuilder
    private var resultPanel: some View {
        if let result {
            resultContent(result)
        } else {
            ContentUnavailableView(
                "No Comparison Results",
                systemImage: "arrow.left.arrow.right",
                description: Text("Enter paths to two Brewfiles and click Compare.")
            )
        }
    }

    private func resultContent(_ result: CellarCore.ComparisonResult) -> some View {
        VStack(spacing: 0) {
            statsBar(result)
            Divider()
            resultList(result)
        }
    }

    private func statsBar(_ result: CellarCore.ComparisonResult) -> some View {
        HStack(spacing: 20) {
            statBadge(
                label: "Only in Source",
                count: result.onlyInSource.count,
                color: .red
            )
            statBadge(
                label: "Only in Target",
                count: result.onlyInTarget.count,
                color: .orange
            )
            statBadge(
                label: "Shared",
                count: result.inBoth.count,
                color: .green
            )
            Spacer()
            Text("\(result.totalDifferences) differences")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.fill.tertiary, in: Capsule())
        }
        .padding()
    }

    private func statBadge(label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(count) \(label)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.08), in: Capsule())
    }

    private func resultList(_ result: CellarCore.ComparisonResult) -> some View {
        List {
            if !result.onlyInSource.isEmpty {
                Section {
                    ForEach(result.onlyInSource, id: \.self) { name in
                        HStack {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                            Text(name)
                                .font(.body.monospaced())
                        }
                    }
                } header: {
                    Label(
                        "Only in \(result.sourceLabel) (\(result.onlyInSource.count))",
                        systemImage: "doc"
                    )
                }
            }

            if !result.onlyInTarget.isEmpty {
                Section {
                    ForEach(result.onlyInTarget, id: \.self) { name in
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.orange)
                            Text(name)
                                .font(.body.monospaced())
                        }
                    }
                } header: {
                    Label(
                        "Only in \(result.targetLabel) (\(result.onlyInTarget.count))",
                        systemImage: "doc"
                    )
                }
            }

            if !result.inBoth.isEmpty {
                Section {
                    ForEach(result.inBoth, id: \.self) { name in
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(name)
                                .font(.body.monospaced())
                        }
                    }
                } header: {
                    Label(
                        "In Both (\(result.inBoth.count))",
                        systemImage: "equal.circle"
                    )
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                isExporting = true
            } label: {
                Label("Export Diff", systemImage: "square.and.arrow.up")
            }
            .disabled(result == nil)
            .help("Export the comparison results as a text file")

            Button {
                sourcePath = ""
                targetPath = ""
                result = nil
                errorMessage = nil
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .help("Clear comparison")
        }
    }

    // MARK: - Comparison Logic

    private func performComparison() {
        errorMessage = nil
        result = nil

        let source = sourcePath.trimmingCharacters(in: .whitespaces)
        let target = targetPath.trimmingCharacters(in: .whitespaces)

        do {
            let sourcePackages = try CellarCore.ComparisonResult.parseBrewfile(at: source)
            let targetPackages = try CellarCore.ComparisonResult.parseBrewfile(at: target)

            let sourceFileName = URL(fileURLWithPath: source).lastPathComponent
            let targetFileName = URL(fileURLWithPath: target).lastPathComponent

            result = CellarCore.ComparisonResult.compare(
                source: sourcePackages,
                target: targetPackages,
                sourceLabel: sourceFileName,
                targetLabel: targetFileName
            )
        } catch {
            errorMessage = "Failed to read Brewfile: \(error.localizedDescription)"
        }
    }

    // MARK: - File Browser

    private func browseForFile() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Select Brewfile"

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url.path
    }

    // MARK: - Export Document

    private var diffDocument: DiffTextDocument? {
        guard let result else { return nil }
        return DiffTextDocument(text: result.exportDiff())
    }
}

// MARK: - DiffTextDocument

/// A simple transferable document for exporting comparison results.
struct DiffTextDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    let text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ComparisonView()
    }
    .frame(width: 800, height: 600)
}
