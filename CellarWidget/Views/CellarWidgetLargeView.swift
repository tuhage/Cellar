import SwiftUI
import WidgetKit

struct CellarWidgetLargeView: View {
    let entry: CellarWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: "mug.fill")
                    .foregroundStyle(.blue)
                Text("Cellar")
                    .font(.headline)
                Spacer()
                Text("\(entry.totalFormulae + entry.totalCasks) packages")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Stats row
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
                    tint: entry.outdatedCount > 0 ? .orange : nil
                )
            }

            Divider()

            // Services section
            VStack(alignment: .leading, spacing: 4) {
                Text("Running Services")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if entry.runningServiceNames.isEmpty {
                    Text("No services running")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(entry.runningServiceNames.prefix(3), id: \.self) { name in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    if entry.runningServiceNames.count > 3 {
                        Text("+\(entry.runningServiceNames.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Outdated section
            if !entry.outdatedPackageNames.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Outdated Packages")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(entry.outdatedPackageNames.prefix(3), id: \.self) { name in
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text(name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    if entry.outdatedPackageNames.count > 3 {
                        Text("+\(entry.outdatedPackageNames.count - 3) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "cellar://dashboard"))
    }

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
}
