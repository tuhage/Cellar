import SwiftUI

/// Live progress of a running operation: what brew is doing, for how long,
/// and a hint when it has gone quiet. Batches (Upgrade All) also show which
/// package is upgrading and how many are left.
struct OperationProgressView: View {
    let operation: BrewOperation

    /// brew stays quiet while pouring or building large packages, so silence
    /// is only called out once it lasts long enough to look like a hang.
    private static let quietThreshold: TimeInterval = 180

    private var isBatch: Bool { !operation.steps.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
                headline
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Spacing.item)
                if isBatch {
                    Text(countLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            progressBar

            TimelineView(.periodic(from: .now, by: 1)) { context in
                detail(at: context.date)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Headline

    @ViewBuilder
    private var headline: some View {
        if operation.isCancelling {
            Text("Cancelling\u{2026}")
        } else if let step = operation.currentStep {
            Text("Upgrading \(Text(step.name).fontWeight(.semibold))")
        } else if isBatch, operation.finishedStepCount == operation.steps.count {
            Text("Refreshing package list\u{2026}")
        } else {
            Text(operation.kind.displayTitle)
        }
    }

    private var countLabel: String {
        let position = operation.currentStepNumber ?? operation.finishedStepCount
        let failed = operation.failedSteps.count
        let count = "\(position) of \(operation.steps.count)"
        return failed > 0 ? "\(count) · \(failed) failed" : count
    }

    @ViewBuilder
    private var progressBar: some View {
        if isBatch {
            ProgressView(
                value: Double(operation.finishedStepCount),
                total: Double(max(operation.steps.count, 1))
            )
            .tint(operation.failedSteps.isEmpty ? Color.accentColor : .orange)
        } else {
            ProgressView()
                .progressViewStyle(.linear)
        }
    }

    // MARK: - Detail

    /// For a batch, the running package; otherwise the whole operation.
    private var currentWork: (startedAt: Date, versions: String?)? {
        if let step = operation.currentStep, let startedAt = step.startedAt {
            return (startedAt, "\(step.currentVersion) → \(step.targetVersion)")
        }
        return isBatch ? nil : (operation.startedAt, nil)
    }

    @ViewBuilder
    private func detail(at now: Date) -> some View {
        if operation.isRunning, !operation.isCancelling, let work = currentWork {
            let quietSince = max(work.startedAt, operation.lastOutputAt ?? work.startedAt)
            let quietFor = now.timeIntervalSince(quietSince)

            Text(detailLine(work, now: now))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)

            if quietFor >= Self.quietThreshold {
                Label(
                    "No output for \(Self.minutes(quietFor)). Large packages can take a while; cancel if it seems stuck.",
                    systemImage: "hourglass"
                )
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "9.7.0 → 9.8.1 · 0:42 · Pouring gradle…". Output printed before the
    /// current package started belongs to the previous one and is left out.
    private func detailLine(_ work: (startedAt: Date, versions: String?), now: Date) -> String {
        var parts = work.versions.map { [$0] } ?? []
        parts.append(
            Duration.seconds(max(0, now.timeIntervalSince(work.startedAt)))
                .formatted(.time(pattern: .minuteSecond))
        )
        if let lastOutputAt = operation.lastOutputAt, lastOutputAt >= work.startedAt,
           let line = operation.lastLogLine {
            parts.append(line)
        }
        return parts.joined(separator: " · ")
    }

    private static func minutes(_ interval: TimeInterval) -> String {
        Duration.seconds(interval).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

// MARK: - Running Operation Bar

/// The page-level strip for an operation started from that page: live
/// progress plus Details (the Activity panel) and Cancel.
struct RunningOperationBar: View {
    let operation: BrewOperation

    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        NoticeBanner(tint: .accentColor, systemImage: operation.kind.symbolName) {
            OperationProgressView(operation: operation)
                .frame(maxWidth: 560, alignment: .leading)
        } actions: {
            Button("Details") {
                NotificationCenter.default.post(name: .openActivityPanel, object: nil)
            }
            .help("Show brew’s output in Activity")

            Button("Cancel") {
                activityStore.cancel(operation.id)
            }
            .disabled(!activityStore.canCancel(operation.id))
        }
    }
}

// MARK: - Preview

#Preview("Batch") {
    OperationProgressView(operation: .upgradeAllPreview)
        .padding()
        .frame(width: 360)
}

#Preview("Single") {
    OperationProgressView(operation: BrewOperation(
        kind: .install(name: "wget", isCask: false),
        log: ["==> Downloading wget"],
        lastOutputAt: .now
    ))
    .padding()
    .frame(width: 360)
}

#Preview("Bar") {
    RunningOperationBar(operation: .upgradeAllPreview)
        .environment(AppStores())
        .frame(width: 720)
}
