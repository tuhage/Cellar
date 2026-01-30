import SwiftUI
import CellarCore

struct SecurityAlertView: View {
    @Environment(PackageStore.self) private var packageStore
    @State private var store = SecurityStore()

    var body: some View {
        Group {
            if store.isLoading {
                LoadingView(message: "Scanning packages\u{2026}")
            } else if let errorMessage = store.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { store.scan(formulae: packageStore.formulae, casks: packageStore.casks) }
                }
            } else if store.alerts.isEmpty && !packageStore.formulae.isEmpty {
                EmptyStateView(
                    title: "No Security Alerts",
                    systemImage: "shield.checkered",
                    description: "All installed packages are in good standing."
                )
            } else if store.alerts.isEmpty {
                EmptyStateView(
                    title: "No Packages Loaded",
                    systemImage: "shield.checkered",
                    description: "Load packages first, then scan for security alerts."
                )
            } else {
                securityContent
            }
        }
        .navigationTitle("Security")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { store.scan(formulae: packageStore.formulae, casks: packageStore.casks) }
                } label: {
                    Label("Scan Now", systemImage: "shield.checkered")
                }
                .disabled(store.isLoading)
            }
        }
        .task {
            if store.alerts.isEmpty {
                await packageStore.loadAll()
                store.scan(formulae: packageStore.formulae, casks: packageStore.casks)
            }
        }
    }

    // MARK: - Content

    private var securityContent: some View {
        List {
            Section {
                alertCountBanner
            }

            ForEach(store.alertsBySeverity, id: \.severity) { group in
                Section {
                    ForEach(group.alerts) { alert in
                        SecurityAlertRow(alert: alert)
                    }
                } header: {
                    HStack {
                        Label(severitySectionTitle(group.severity), systemImage: severitySectionIcon(group.severity))
                            .foregroundStyle(group.severity.color)
                        Spacer()
                        Text("\(group.alerts.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Alert Count Banner

    private var alertCountBanner: some View {
        let bannerColor: Color = store.hasCriticalAlerts ? .red : .orange

        return HStack(spacing: 12) {
            Image(systemName: store.hasCriticalAlerts ? "shield.fill" : "shield.checkered")
                .font(.largeTitle)
                .foregroundStyle(bannerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(store.alertCount) Alert\(store.alertCount == 1 ? "" : "s") Found")
                    .font(.headline)

                let criticalCount = store.alerts.filter { $0.severity == .critical }.count
                let highCount = store.alerts.filter { $0.severity == .high }.count

                Text(alertSummary(critical: criticalCount, high: highCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(bannerColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Helpers

    private func alertSummary(critical: Int, high: Int) -> String {
        var parts: [String] = []
        if critical > 0 { parts.append("\(critical) critical") }
        if high > 0 { parts.append("\(high) high") }
        let remaining = store.alertCount - critical - high
        if remaining > 0 { parts.append("\(remaining) other") }
        return parts.joined(separator: ", ")
    }

    private func severitySectionTitle(_ severity: SecuritySeverity) -> String {
        switch severity {
        case .critical: "Critical"
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        }
    }

    private func severitySectionIcon(_ severity: SecuritySeverity) -> String {
        switch severity {
        case .critical: "xmark.octagon.fill"
        case .high: "exclamationmark.triangle.fill"
        case .medium: "exclamationmark.circle.fill"
        case .low: "info.circle.fill"
        }
    }
}

// MARK: - SecurityAlertRow

private struct SecurityAlertRow: View {
    let alert: SecurityAlert

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: alert.alertType.icon)
                    .foregroundStyle(alert.severity.color)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.packageName)
                        .fontWeight(.medium)

                    Text(alert.alertType.title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(alert.severity.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(alert.severity.color)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                expandedContent
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(alert.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.blue)
                    .frame(width: 3)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)

                    Text(alert.recommendation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(.leading, 24)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SecurityAlertView()
            .environment(PackageStore())
    }
    .frame(width: 600, height: 500)
}
