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
            SectionHeaderView(title: "Disk Usage", systemImage: "internaldrive", color: .blue)

            diskOverviewCard

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
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

    private var diskOverviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "internaldrive.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.blue.gradient, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Homebrew Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(store.diskUsage?.homebrewTotal ?? "--")
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .contentTransition(.numericText())
                }

                Spacer()
            }

            if let diskUsage = store.diskUsage {
                storageBreakdownBar(diskUsage: diskUsage)
            }
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func storageBreakdownBar(diskUsage: DiskUsage) -> some View {
        let total = parseSizeToMB(diskUsage.homebrewTotal) ?? 1
        let cellar = parseSizeToMB(diskUsage.cellarSize) ?? 0
        let cache = parseSizeToMB(diskUsage.cacheSize) ?? 0
        let other = max(total - cellar - cache, 0)

        let cellarFraction = total > 0 ? cellar / total : 0
        let cacheFraction = total > 0 ? cache / total : 0

        VStack(spacing: 8) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    if cellarFraction > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.purple)
                            .frame(width: max(geometry.size.width * cellarFraction, 4))
                    }
                    if cacheFraction > 0 {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: max(geometry.size.width * cacheFraction, 4))
                    }
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.primary.opacity(0.08))
                }
            }
            .frame(height: 8)
            .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack(spacing: 16) {
                breakdownLegendItem(color: .purple, label: "Cellar", value: diskUsage.cellarSize)
                breakdownLegendItem(color: .orange, label: "Cache", value: diskUsage.cacheSize)
                if other > 0.5 {
                    breakdownLegendItem(
                        color: Color.primary.opacity(0.08),
                        label: "Other",
                        value: formatMB(other)
                    )
                }
                Spacer()
            }
        }
    }

    private func breakdownLegendItem(color: Color, label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
        }
    }

    // MARK: - Service Resource Section

    private var serviceResourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderView(
                title: "Service Resources",
                systemImage: "gauge.with.dots.needle.33percent",
                color: .green
            ) {
                if !store.usages.isEmpty {
                    Text("\(store.usages.count) running")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if store.sortedUsages.isEmpty {
                serviceEmptyState
            } else {
                resourceSummary
                resourceTable
            }
        }
    }

    private var serviceEmptyState: some View {
        HStack(spacing: 14) {
            Image(systemName: "gauge.with.dots.needle.0percent")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            VStack(alignment: .leading, spacing: 2) {
                Text("No Running Services")
                    .font(.subheadline.weight(.medium))
                Text("Start a Homebrew service to see its resource usage.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private func formatMB(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024.0)
        }
        return String(format: "%.0f MB", mb)
    }

    private func parseSizeToMB(_ sizeString: String) -> Double? {
        let parts = sizeString.split(separator: " ")
        guard parts.count == 2, let value = Double(parts[0]) else { return nil }
        switch parts[1] {
        case "KB": return value / 1024.0
        case "MB": return value
        case "GB": return value * 1024.0
        case "TB": return value * 1024.0 * 1024.0
        default: return nil
        }
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
