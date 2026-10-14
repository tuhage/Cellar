import SwiftUI
import Charts
import CellarCore

/// CPU and memory of a running service: the latest sample and a chart of
/// the last few minutes. Samples come from `ServiceMetricsStore`, which the
/// Services page keeps sampling while it is visible.
struct ServiceUsageSection: View {
    let service: BrewServiceItem

    @Environment(ServiceMetricsStore.self) private var metrics

    var body: some View {
        let history = metrics.history(for: service)

        VStack(alignment: .leading, spacing: Spacing.sectionContent) {
            Text("Usage")
                .font(.headline)

            if let usage = metrics.usage(for: service) {
                MetricHistoryChart(
                    title: "CPU",
                    current: usage.cpuText,
                    samples: history,
                    value: \.cpuPercent,
                    minimumScale: 1,
                    format: ResourceUsage.formattedCPU
                )
                MetricHistoryChart(
                    title: "Memory",
                    current: usage.memoryText,
                    samples: history,
                    value: { Double($0.memoryBytes) },
                    minimumScale: 1_048_576,
                    format: { ResourceUsage.formattedMemory(Int64($0)) }
                )
                Text(footnote(for: usage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Measuring\u{2026}")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func footnote(for usage: ResourceUsage) -> String {
        let processes = String.count(usage.processCount, "process")
        return "Includes \(processes). 100% CPU is one full core."
    }
}

// MARK: - Chart

/// One measure over the last few minutes. CPU and memory get a chart each
/// rather than sharing one with two y-axes. Hovering shows a sample's value.
private struct MetricHistoryChart: View {
    let title: String
    let current: String
    let samples: [ResourceUsage]
    let value: (ResourceUsage) -> Double
    /// The smallest top of the y-axis, so an idle service doesn't get an
    /// axis from 0.0% to 0.0%.
    let minimumScale: Double
    let format: (Double) -> String

    @State private var hoveredDate: Date?

    private static let height: CGFloat = 72

    private var hoveredSample: ResourceUsage? {
        guard let hoveredDate else { return nil }
        return samples.min { abs($0.timestamp.timeIntervalSince(hoveredDate)) < abs($1.timestamp.timeIntervalSince(hoveredDate)) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.compact) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(hoveredSample.map { format(value($0)) } ?? current)
                    .monospacedDigit()
                    .fontWeight(.medium)
            }
            .font(.callout)

            chart
                .frame(height: Self.height)
                .accessibilityLabel("\(title) over the last \(Int(ServiceMetricsStore.historyWindow / 60)) minutes")
                .accessibilityValue("Now \(current)")
        }
    }

    private var chart: some View {
        Chart {
            // Samples share their service's id, so the time tells them apart.
            ForEach(samples, id: \.timestamp) { sample in
                AreaMark(x: .value("Time", sample.timestamp), y: .value(title, value(sample)))
                    .foregroundStyle(.tint.opacity(Opacity.badgeBackground))
                LineMark(x: .value("Time", sample.timestamp), y: .value(title, value(sample)))
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let hoveredSample {
                RuleMark(x: .value("Time", hoveredSample.timestamp))
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: Date.now.addingTimeInterval(-ServiceMetricsStore.historyWindow)...Date.now)
        .chartYScale(domain: 0...max(samples.map(value).max() ?? 0, minimumScale))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 2)) { axisValue in
                AxisGridLine()
                AxisValueLabel {
                    if let number = axisValue.as(Double.self) {
                        Text(format(number))
                    }
                }
            }
        }
        .chartXSelection(value: $hoveredDate)
    }
}

// MARK: - Preview

#Preview {
    ServiceUsageSection(service: .preview)
        .padding()
        .frame(width: 400)
        .environment(AppStores())
}
