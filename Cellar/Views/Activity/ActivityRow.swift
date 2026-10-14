import SwiftUI

/// One operation in the Activity panel: what it did, when, how it ended,
/// and what can be done next (cancel, retry, open the log).
struct ActivityRow: View {
    let operation: BrewOperation

    @Environment(ActivityStore.self) private var store
    @State private var isOutputExpanded = false
    @State private var isStepsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.item) {
            header

            if operation.isRunning {
                OperationProgressView(operation: operation)
            } else if case .failed(let reason) = operation.status {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .textSelection(.enabled)
            }

            if operation.isBatch {
                stepsDisclosure
            }
            if !operation.log.isEmpty {
                outputDisclosure
            }
            if !operation.isRunning {
                actions
            }
        }
        .padding(.vertical, Spacing.item)
        .contextMenu { contextMenu }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: Spacing.item) {
            Image(systemName: operation.kind.symbolName)
                .font(.title3)
                .foregroundStyle(operation.status.color)
                .frame(width: IconSize.smallIcon)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                Text(operation.title)
                    .font(.subheadline.weight(.medium))
                timing
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: Spacing.item)

            if operation.isRunning {
                CancelOperationButton(operation: operation) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Cancel")
                .accessibilityLabel("Cancel \(operation.kind.displayTitle)")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(statusDescription)
    }

    @ViewBuilder
    private var timing: some View {
        if let completedAt = operation.completedAt {
            Text("\(statusDescription) \(completedAt, style: .relative) ago · took \(Duration.elapsed(from: operation.startedAt, to: completedAt))")
        } else {
            Text("Started \(operation.startedAt, style: .relative) ago")
        }
    }

    private var statusDescription: String {
        operation.isCancelling ? "Cancelling" : operation.status.label
    }

    // MARK: - Disclosures

    private var stepsDisclosure: some View {
        DisclosureGroup(isExpanded: $isStepsExpanded) {
            ScrollView {
                BatchStepList(steps: operation.steps)
                    .padding(.vertical, Spacing.compact)
            }
            .frame(maxHeight: 180)
        } label: {
            Text(stepsTitle)
                .font(.caption)
                .foregroundStyle(operation.failedSteps.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
        }
    }

    private var stepsTitle: String {
        let failed = operation.failedSteps.count
        let upgraded = operation.succeededStepCount
        return failed > 0
            ? "Packages · \(upgraded) upgraded, \(failed) failed"
            : "Packages · \(upgraded) of \(operation.steps.count) upgraded"
    }

    private var outputDisclosure: some View {
        DisclosureGroup(isExpanded: $isOutputExpanded) {
            ScrollView {
                Text(operation.log.joined(separator: "\n"))
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .defaultScrollAnchor(.bottom)
            .frame(maxHeight: 160)
        } label: {
            Text("Output")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: Spacing.item) {
            Spacer()
            if store.canRetry(operation.id) {
                Button("Retry", systemImage: "arrow.clockwise") {
                    Task { await store.retry(operation.id) }
                }
            }
            if let logFileURL = operation.logFileURL {
                FileActions(path: logFileURL.path(percentEncoded: false), openTitle: "Open Log")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .font(.caption)
    }

    @ViewBuilder
    private var contextMenu: some View {
        if case .failed(let reason) = operation.status {
            Button("Copy Error") { NSPasteboard.copy(reason) }
        }
        if store.canRetry(operation.id) {
            Button("Retry") { Task { await store.retry(operation.id) } }
        }
        if let logFileURL = operation.logFileURL {
            Button("Open Log") { NSWorkspace.shared.open(logFileURL) }
            Button("Show Log in Finder") { NSWorkspace.shared.activateFileViewerSelecting([logFileURL]) }
        }
        if !operation.isRunning {
            Divider()
            Button("Remove from List") { store.remove(operation.id) }
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        ForEach(BrewOperation.previewList) { operation in
            ActivityRow(operation: operation)
            Divider()
        }
    }
    .padding(.horizontal)
    .frame(width: 380)
    .environment(AppStores(activity: .preview(BrewOperation.previewList)))
}
