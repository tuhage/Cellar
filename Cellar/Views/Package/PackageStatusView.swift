import SwiftUI
import CellarCore

// MARK: - PackageActivity

/// What Cellar is doing with a package right now.
enum PackageActivity: Equatable {
    /// Its place in a running batch such as Upgrade All — finished steps
    /// included, so rows show a checkmark until the batch ends.
    case batchStep(BrewOperation.StepStatus)
    /// A single operation on it, such as an install or a service restart.
    case operation(BrewOperation.Kind)

    init?(_ package: PackageType, activityStore: ActivityStore) {
        if let step = activityStore.runningBatchStep(name: package.identifier, isCask: package.kind == .cask) {
            self = .batchStep(step.status)
        } else if let operation = activityStore.runningOperation(for: .package(package.identifier)) {
            self = .operation(operation.kind)
        } else {
            return nil
        }
    }

    /// "Upgrading…", "Waiting" — short enough for a button or table cell.
    var label: String {
        switch self {
        case .batchStep(let status): status.label
        case .operation(let kind): kind.progressLabel
        }
    }
}

private extension BrewOperation.Kind {

    var progressLabel: String {
        switch self {
        case .install: "Installing\u{2026}"
        case .upgrade, .upgradeAll: "Upgrading\u{2026}"
        case .reinstall: "Reinstalling\u{2026}"
        case .uninstall: "Uninstalling\u{2026}"
        case .pin: "Pinning\u{2026}"
        case .unpin: "Unpinning\u{2026}"
        case .serviceStart, .serviceRun: "Starting\u{2026}"
        case .serviceStop: "Stopping\u{2026}"
        case .serviceRestart: "Restarting\u{2026}"
        case .serviceForceQuit: "Quitting\u{2026}"
        default: "Working\u{2026}"
        }
    }
}

// MARK: - PackageActivityLabel

/// A spinner or batch status glyph with a short label.
struct PackageActivityLabel: View {
    let activity: PackageActivity

    var body: some View {
        HStack(spacing: Spacing.compact) {
            switch activity {
            case .batchStep(let status):
                StepStatusIcon(status: status)
                    .accessibilityHidden(true)
            case .operation:
                ProgressView()
                    .controlSize(.mini)
            }
            Text(activity.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .help(help)
    }

    private var help: String {
        if case .batchStep(.failed(let reason)) = activity { return reason }
        return activity.label
    }
}

// MARK: - PackageStatusView

/// A package's current activity, or badges for its state: outdated,
/// pinned, deprecated and so on.
struct PackageStatusView: View {
    let package: PackageType

    @Environment(ActivityStore.self) private var activityStore

    var body: some View {
        if let activity = PackageActivity(package, activityStore: activityStore) {
            PackageActivityLabel(activity: activity)
        } else {
            PackageBadges(package: package)
        }
    }
}

/// The state badges of a package; each says its state in words.
struct PackageBadges: View {
    let package: PackageType
    /// Also show slower-changing traits such as keg-only and auto-updates.
    var showsTraits = true

    var body: some View {
        HStack(spacing: Spacing.related) {
            ForEach(badges, id: \.text) { badge in
                StatusBadge(text: badge.text, color: badge.color)
            }
        }
    }

    private var badges: [(text: String, color: Color)] {
        guard package.isInstalled else { return [] }
        var badges: [(text: String, color: Color)] = []
        if package.isOutdated { badges.append(("Outdated", .orange)) }
        if package.isPinned { badges.append(("Pinned", .blue)) }
        if package.isDeprecated { badges.append(("Deprecated", .red)) }
        guard showsTraits else { return badges }
        switch package {
        case .formula(let formula):
            if formula.isKegOnly { badges.append(("Keg-only", .purple)) }
            if formula.disabled { badges.append(("Disabled", .gray)) }
        case .cask(let cask):
            if cask.autoUpdates { badges.append(("Auto-updates", .green)) }
        }
        return badges
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.item) {
        PackageStatusView(package: .formula(.preview))
        PackageStatusView(package: .cask(.preview))
        PackageActivityLabel(activity: .operation(.upgrade(name: "wget", isCask: false)))
        PackageActivityLabel(activity: .batchStep(.pending))
        PackageActivityLabel(activity: .batchStep(.failed(reason: "Download failed")))
    }
    .padding()
    .environment(AppStores())
}
