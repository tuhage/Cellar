import SwiftUI
import CellarCore

// MARK: - ResourceMonitorView

struct ResourceMonitorView: View {
    @Environment(ServiceStore.self) private var serviceStore
    @Environment(ResourceStore.self) private var store

    var body: some View {
        Group {
            if store.isLoading && store.diskUsage == nil && store.usages.isEmpty {
                LoadingView(message: "Loading resources\u{2026}")
            } else if let errorMessage = store.errorMessage,
                      store.diskUsage == nil && store.usages.isEmpty {
                ErrorView(message: errorMessage) {
                    Task { await refresh() }
                }
            } else {
                resourceContent
            }
        }
        .navigationTitle("Resources")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
            }
        }
        .task {
            await refresh()
            await autoRefresh()
        }
    }

    // MARK: - Content

    private var resourceContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                diskUsageSection
                serviceResourceSection
            }
            .padding(24)
        }
    }

    // MARK: - Disk Usage Section

    private var diskUsageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Disk Usage")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: 16)],
                spacing: 16
            ) {
                StatCardView(
                    title: "Homebrew Total",
                    value: store.diskUsage?.homebrewTotal ?? "--",
                    systemImage: "internaldrive",
                    color: .blue
                )

                StatCardView(
                    title: "Cellar",
                    value: store.diskUsage?.cellarSize ?? "--",
                    systemImage: "shippingbox",
                    color: .purple
                )

                StatCardView(
                    title: "Cache",
                    value: store.diskUsage?.cacheSize ?? "--",
                    systemImage: "archivebox",
                    color: .orange
                )
            }
        }
    }

    // MARK: - Service Resource Section

    private var serviceResourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Service Resources")
                    .font(.headline)

                Spacer()

                if !store.usages.isEmpty {
                    Text("\(store.usages.count) running")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if store.sortedUsages.isEmpty {
                GroupBox {
                    EmptyStateView(
                        title: "No Running Services",
                        systemImage: "gauge.with.dots.needle.0percent",
                        description: "Start a Homebrew service to see its resource usage."
                    )
                    .frame(maxWidth: .infinity, minHeight: 150)
                }
            } else {
                resourceTable
                resourceSummary
            }
        }
    }

    // MARK: - Resource Table

    private var resourceTable: some View {
        GroupBox {
            Table(store.sortedUsages) {
                TableColumn("Service") { usage in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)

                        Text(usage.serviceName)
                            .fontWeight(.medium)
                    }
                }
                .width(min: 120, ideal: 200)

                TableColumn("PID") { usage in
                    Text("\(usage.pid)")
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }
                .width(min: 60, ideal: 80)

                TableColumn("CPU %") { usage in
                    HStack(spacing: 6) {
                        cpuBar(percent: usage.cpuPercent)

                        Text(formatPercent(usage.cpuPercent))
                            .font(.body.monospaced())
                            .foregroundStyle(cpuColor(for: usage.cpuPercent))
                    }
                }
                .width(min: 100, ideal: 140)

                TableColumn("Memory (MB)") { usage in
                    Text(formatMemory(usage.memoryMB))
                        .font(.body.monospaced())
                        .foregroundStyle(memoryColor(for: usage.memoryMB))
                }
                .width(min: 80, ideal: 120)
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: CGFloat(store.sortedUsages.count) * 32 + 32)
        }
    }

    // MARK: - Resource Summary

    private var resourceSummary: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .foregroundStyle(.blue)
                Text("CPU: \(formatPercent(store.totalCPU))")
                    .font(.callout.monospaced())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.blue.opacity(0.08), in: Capsule())

            HStack(spacing: 6) {
                Image(systemName: "memorychip")
                    .foregroundStyle(.purple)
                Text("Memory: \(formatMemory(store.totalMemoryMB))")
                    .font(.callout.monospaced())
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.purple.opacity(0.08), in: Capsule())

            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Helpers

    private func refresh() async {
        await store.loadAll(services: serviceStore.services)
    }

    private func autoRefresh() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { break }
            await store.loadResourceUsage(for: serviceStore.services)
        }
    }

    // MARK: - Formatting

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatMemory(_ mb: Double) -> String {
        String(format: "%.1f MB", mb)
    }

    private func cpuColor(for percent: Double) -> Color {
        if percent > 80 { return .red }
        if percent > 40 { return .orange }
        return .primary
    }

    private func memoryColor(for mb: Double) -> Color {
        if mb > 500 { return .red }
        if mb > 200 { return .orange }
        return .primary
    }

    private func cpuBar(percent: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.quaternary)

                RoundedRectangle(cornerRadius: 4)
                    .fill(cpuColor(for: percent))
                    .frame(width: geometry.size.width * min(percent / 100.0, 1.0))
            }
        }
        .frame(width: 60, height: 8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResourceMonitorView()
    }
    .environment(ServiceStore())
    .environment(ResourceStore())
    .frame(width: 700, height: 600)
}
