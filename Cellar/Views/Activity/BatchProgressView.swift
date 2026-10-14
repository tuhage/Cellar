import SwiftUI

/// Live progress of a batch operation such as Upgrade All: the package being
/// upgraded, its position in the batch, how long it has been running, and
/// brew's latest output line.
struct BatchProgressView: View {
    let operation: BrewOperation

    /// brew stays quiet while pouring or building large packages, so silence
    /// is only called out once it lasts long enough to look like a hang.
    private static let quietThreshold: TimeInterval = 180

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.item) {
                headline
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Spacing.item)
                Text(countLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(
                value: Double(operation.finishedStepCount),
                total: Double(max(operation.steps.count, 1))
            )
            .progressViewStyle(.linear)
            .tint(operation.failedSteps.isEmpty ? Color.accentColor : .orange)

            TimelineView(.periodic(from: .now, by: 1)) { context in
                detail(at: context.date)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Headline

    @ViewBuilder
    private var headline: some View {
        if !operation.isRunning {
            Text("Cancelling\u{2026}")
        } else if let step = operation.currentStep {
            Text("Upgrading \(Text(step.name).fontWeight(.semibold))")
        } else if operation.finishedStepCount == operation.steps.count {
            Text("Refreshing package list\u{2026}")
        } else {
            Text("Preparing\u{2026}")
        }
    }

    private var countLabel: String {
        let position = operation.currentStepNumber ?? operation.finishedStepCount
        let failed = operation.failedSteps.count
        let count = "\(position) of \(operation.steps.count)"
        return failed > 0 ? "\(count) · \(failed) failed" : count
    }

    // MARK: - Detail

    @ViewBuilder
    private func detail(at now: Date) -> some View {
        if operation.isRunning, let step = operation.currentStep, let startedAt = step.startedAt {
            let quietSince = max(startedAt, operation.lastOutputAt ?? startedAt)
            let quietFor = now.timeIntervalSince(quietSince)

            Text(stepDetail(step, startedAt: startedAt, now: now))
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

    /// "9.7.0 → 9.8.1 · 0:42 · Pouring gradle…". Output printed before this
    /// package started belongs to the previous one and is left out.
    private func stepDetail(_ step: BrewOperation.Step, startedAt: Date, now: Date) -> String {
        var parts = [
            "\(step.currentVersion) → \(step.targetVersion)",
            Duration.seconds(max(0, now.timeIntervalSince(startedAt)))
                .formatted(.time(pattern: .minuteSecond)),
        ]
        if let lastOutputAt = operation.lastOutputAt, lastOutputAt >= startedAt,
           let line = operation.lastLogLine {
            parts.append(line)
        }
        return parts.joined(separator: " · ")
    }

    private static func minutes(_ interval: TimeInterval) -> String {
        Duration.seconds(interval).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }
}

// MARK: - Preview

#Preview("Upgrading") {
    BatchProgressView(operation: .upgradeAllPreview)
        .padding()
        .frame(width: 360)
}

extension BrewOperation {
    static var upgradeAllPreview: BrewOperation {
        var steps = [
            Step(name: "docker", isCask: false, currentVersion: "29.8.0", targetVersion: "29.9.0"),
            Step(name: "maestro", isCask: false, currentVersion: "2.10.0", targetVersion: "2.11.0"),
            Step(name: "gradle", isCask: false, currentVersion: "9.7.0", targetVersion: "9.8.1"),
            Step(name: "openjdk@17", isCask: false, currentVersion: "17.0.20", targetVersion: "17.0.20.1"),
            Step(name: "tailscale", isCask: false, currentVersion: "1.102.2", targetVersion: "1.104.1"),
        ]
        steps[0].status = .succeeded
        steps[1].status = .failed(reason: "Cask 'maestro' is not installed.")
        steps[2].status = .running
        steps[2].startedAt = Date().addingTimeInterval(-42)
        return BrewOperation(
            kind: .upgradeAll(count: steps.count),
            log: ["==> Upgrading gradle", "==> Pouring gradle--9.8.1.all.bottle.tar.gz"],
            lastOutputAt: Date().addingTimeInterval(-5),
            steps: steps
        )
    }
}
