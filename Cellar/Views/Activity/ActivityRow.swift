import SwiftUI

/// Single row in the activity panel — one `BrewOperation`.
struct ActivityRow: View {
    let operation: BrewOperation
    let onCancel: (() -> Void)?

    @State private var isLogExpanded = false

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
                    Text(statusLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusIndicator
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

    private var statusLabel: String {
        switch operation.status {
        case .running:
            "Running"
        case .succeeded:
            "Completed"
        case .failed(let reason):
            "Failed — \(reason)"
        case .cancelled:
            "Cancelled"
        }
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
        onCancel: {}
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
        onCancel: nil
    )
    .padding()
    .frame(width: 340)
}
