import SwiftUI

struct HealthCheckView: View {
    @State private var store = HealthStore()

    var body: some View {
        Group {
            if store.isLoading {
                LoadingView(message: "Running diagnostics\u{2026}")
            } else if let errorMessage = store.errorMessage {
                ErrorView(message: errorMessage) {
                    Task { await store.runDiagnostics() }
                }
            } else if store.checks.isEmpty {
                EmptyStateView(
                    title: "No Diagnostics Run",
                    systemImage: "heart.text.square",
                    description: "Click \"Run Diagnostics\" to check your Homebrew installation."
                )
            } else {
                healthContent
            }
        }
        .navigationTitle("Health")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await store.runDiagnostics() }
                } label: {
                    Label("Run Diagnostics", systemImage: "stethoscope")
                }
                .disabled(store.isLoading)
            }
        }
        .task {
            if store.checks.isEmpty {
                await store.runDiagnostics()
            }
        }
    }

    // MARK: - Content

    private var healthContent: some View {
        List {
            Section {
                healthStatusBanner
            }

            ForEach(store.checksBySeverity, id: \.severity) { group in
                Section {
                    ForEach(group.checks) { check in
                        HealthCheckRow(check: check)
                    }
                } header: {
                    HStack {
                        Label(severitySectionTitle(group.severity), systemImage: group.severity.icon)
                            .foregroundStyle(group.severity.color)
                        Spacer()
                        Text("\(group.checks.count)")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
        }
    }

    // MARK: - Status Banner

    private var healthStatusBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: store.isHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(store.isHealthy ? .green : .yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.isHealthy ? "System Healthy" : "Issues Found")
                    .font(.headline)

                Text(store.isHealthy
                     ? "Your Homebrew installation is in good shape."
                     : "\(store.checks.filter { $0.severity != .info }.count) issue(s) require attention.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func severitySectionTitle(_ severity: HealthSeverity) -> String {
        switch severity {
        case .critical: "Critical"
        case .warning: "Warnings"
        case .info: "Info"
        }
    }
}

// MARK: - HealthCheckRow

private struct HealthCheckRow: View {
    let check: HealthCheck

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: check.severity.icon)
                    .foregroundStyle(check.severity.color)
                    .font(.body)

                VStack(alignment: .leading, spacing: 4) {
                    Text(check.title)
                        .fontWeight(.medium)
                        .lineLimit(isExpanded ? nil : 2)

                    HStack(spacing: 6) {
                        Label(check.category.title, systemImage: check.category.icon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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
            Text(check.description)
                .font(.callout)
                .foregroundStyle(.secondary)

            if let solution = check.solution {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text(solution)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(.leading, 24)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HealthCheckView()
    }
    .frame(width: 600, height: 500)
}
