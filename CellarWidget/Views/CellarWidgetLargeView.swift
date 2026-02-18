import SwiftUI
import WidgetKit

struct CellarWidgetLargeView: View {
    let entry: CellarWidgetEntry

    private var totalPackages: Int {
        entry.totalFormulae + entry.totalCasks
    }

    private var outdatedTint: Color? {
        entry.outdatedCount > 0 ? .orange : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            statsRow
            Divider()
            servicesSection

            if !entry.outdatedPackageNames.isEmpty {
                Divider()
                outdatedSection
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("Updated \(entry.lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "cellar://dashboard"))
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Image(systemName: "mug.fill")
                .foregroundStyle(.blue)
            Text("Cellar")
                .font(.headline)
            Spacer()
            Text("\(totalPackages) packages")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(value: entry.totalFormulae, label: "Formulae", icon: "terminal")
            statItem(value: entry.totalCasks, label: "Casks", icon: "macwindow")
            statItem(
                value: entry.runningServices,
                label: "Services",
                icon: "gearshape.2",
                detail: "/\(entry.totalServices)"
            )
            statItem(
                value: entry.outdatedCount,
                label: "Outdated",
                icon: "arrow.triangle.2.circlepath",
                tint: outdatedTint
            )
        }
    }

    private var servicesSection: some View {
        itemListSection(
            title: "Running Services",
            items: entry.runningServiceNames,
            maxVisible: 3,
            emptyText: "No services running"
        ) { name in
            HStack(spacing: 4) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }

    private var outdatedSection: some View {
        itemListSection(
            title: "Outdated Packages",
            items: entry.outdatedPackageNames,
            maxVisible: 3
        ) { name in
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Helpers

    private func statItem(
        value: Int,
        label: String,
        icon: String,
        detail: String? = nil,
        tint: Color? = nil
    ) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(tint ?? .secondary)
            HStack(spacing: 0) {
                Text("\(value)")
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func itemListSection<Content: View>(
        title: String,
        items: [String],
        maxVisible: Int,
        emptyText: String? = nil,
        @ViewBuilder row: @escaping (String) -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if items.isEmpty, let emptyText {
                Text(emptyText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items.prefix(maxVisible), id: \.self) { item in
                    row(item)
                }
                if items.count > maxVisible {
                    Text("+\(items.count - maxVisible) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview(as: .systemLarge) {
    CellarWidget()
} timeline: {
    CellarWidgetEntry.placeholder
}
