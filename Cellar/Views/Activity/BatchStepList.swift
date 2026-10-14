import SwiftUI

/// Per-package status of a batch operation such as Upgrade All.
struct BatchStepList: View {
    let steps: [BrewOperation.Step]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.related) {
            ForEach(steps) { step in
                BatchStepRow(step: step)
            }
        }
    }
}

// MARK: - Row

private struct BatchStepRow: View {
    let step: BrewOperation.Step

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
            StepStatusIcon(status: step.status)
                .frame(width: IconSize.iconColumn)

            VStack(alignment: .leading, spacing: Spacing.textPair) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.compact) {
                    Text(step.name)
                        .font(.caption)
                        .fontWeight(step.status == .running ? .semibold : .regular)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.compact)
                    Text("\(step.currentVersion) → \(step.targetVersion)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if case .failed(let reason) = step.status {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(step.status.label)
    }
}

// MARK: - Status Icon

/// Status glyph for one package in a batch; a spinner while it runs.
struct StepStatusIcon: View {
    let status: BrewOperation.StepStatus

    var body: some View {
        if status == .running {
            ProgressView()
                .controlSize(.mini)
        } else {
            Image(systemName: status.symbolName)
                .font(.caption)
                .foregroundStyle(status.color)
                .accessibilityLabel(status.label)
        }
    }
}

// MARK: - Preview

#Preview {
    BatchStepList(steps: BrewOperation.upgradeAllPreview.steps)
        .padding()
        .frame(width: 340)
}
