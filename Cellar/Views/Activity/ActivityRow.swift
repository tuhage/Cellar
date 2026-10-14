import SwiftUI

/// Single row in the activity panel — one `BrewOperation`.
struct ActivityRow: View {
    let operation: BrewOperation
    let onCancel: (() -> Void)?
    let onForceRetry: (() -> Void)?
    var onRetry: (() -> Void)?

    @State private var isLogExpanded = false
    @State private var isStepsExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            HStack(alignment: .top, spacing: Spacing.item) {
                Image(systemName: operation.kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: IconSize.headerIcon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(operation.kind.displayTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !operation.isRunning {
                        Text(statusLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(operation.isRunning ? 1 : nil)
                            .truncationMode(.tail)
                    }
                }
                Spacer()
                statusIndicator
            }

            if operation.isRunning {
                OperationProgressView(operation: operation)
            }

            if case .failed = operation.status, let onForceRetry {
                HStack {
                    Spacer()
                    Button(action: onForceRetry) {
                        Label("Retry (force)", systemImage: "arrow.clockwise.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .tint(.orange)
                }
                .padding(.top, Spacing.compact)
            }

            if !operation.steps.isEmpty {
                DisclosureGroup(isExpanded: $isStepsExpanded) {
                    ScrollView {
                        BatchStepList(steps: operation.steps)
                            .padding(.vertical, Spacing.compact)
                    }
                    .frame(maxHeight: 180)
                } label: {
                    Text(stepsDisclosureTitle)
                        .font(.caption)
                        .foregroundStyle(operation.failedSteps.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.red))
                }
            }

            if onRetry != nil || operation.logFileURL != nil {
                actionButtons
            }

            if !operation.log.isEmpty {
                DisclosureGroup(isExpanded: $isLogExpanded) {
                    ScrollView {
                        Text(operation.log.joined(separator: "\n"))
                            .font(.system(size: 11, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 140)
                    .padding(.vertical, Spacing.compact)
                } label: {
                    Text("Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, Spacing.item)
    }

    private var actionButtons: some View {
        HStack(spacing: Spacing.item) {
            Spacer()
            if let onRetry {
                Button(action: onRetry) {
                    Label("Retry", systemImage: "arrow.clockwise")
                }
                .help("Run the operation again")
            }
            if let logFileURL = operation.logFileURL {
                Button {
                    NSWorkspace.shared.open(logFileURL)
                } label: {
                    Label("Open Log", systemImage: "doc.text")
                }
                .help("Open the full log in Console")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .font(.caption)
    }

    private var statusLabel: String {
        if !operation.steps.isEmpty {
            return batchStatusLabel
        }
        switch operation.status {
        case .running:
            return operation.lastLogLine ?? "Running"
        case .succeeded:
            return "Completed"
        case .failed(let reason):
            return "Failed — \(reason)"
        case .cancelled:
            return "Cancelled"
        }
    }

    private var batchStatusLabel: String {
        let upgraded = operation.succeededStepCount
        let failed = operation.failedSteps.count
        switch operation.status {
        case .running:
            return "Running"
        case .succeeded:
            return "\(upgraded) upgraded"
        case .failed:
            return "\(upgraded) upgraded, \(failed) failed"
        case .cancelled:
            return "Cancelled after upgrading \(upgraded) of \(operation.steps.count)"
        }
    }

    private var stepsDisclosureTitle: String {
        let failed = operation.failedSteps.count
        return failed > 0 ? "Packages (\(failed) failed)" : "Packages"
    }

    @ViewBuilder
    private var statusIndicator: some View {
        switch operation.status {
        case .running:
            HStack(spacing: Spacing.item) {
                ProgressView().controlSize(.small)
                if let onCancel {
                    Button(role: .cancel, action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Cancel")
                }
            }
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
        case .cancelled:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Running") {
    ActivityRow(
        operation: BrewOperation(
            kind: .upgrade(name: "openssl@3", isCask: false),
            log: ["Downloading openssl@3-3.6.0.bottle.tar.gz", "Installing openssl@3"]
        ),
        onCancel: {},
        onForceRetry: nil
    )
    .padding()
    .frame(width: 340)
}

#Preview("Upgrade All") {
    ActivityRow(
        operation: .upgradeAllPreview,
        onCancel: {},
        onForceRetry: nil
    )
    .padding()
    .frame(width: 340)
}

#Preview("Succeeded") {
    ActivityRow(
        operation: BrewOperation(
            kind: .install(name: "wget", isCask: false),
            status: .succeeded,
            completedAt: Date()
        ),
        onCancel: nil,
        onForceRetry: nil
    )
    .padding()
    .frame(width: 340)
}

#Preview("Failed with force retry") {
    ActivityRow(
        operation: BrewOperation(
            kind: .uninstall(name: "openssl@3", isCask: false),
            status: .failed(reason: "Refusing to uninstall openssl@3 because it is required by curl"),
            completedAt: Date()
        ),
        onCancel: nil,
        onForceRetry: {}
    )
    .padding()
    .frame(width: 340)
}
