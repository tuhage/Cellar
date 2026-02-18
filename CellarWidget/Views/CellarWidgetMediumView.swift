import SwiftUI
import WidgetKit

struct CellarWidgetMediumView: View {
    let entry: CellarWidgetEntry

    private var outdatedTint: Color {
        entry.outdatedCount > 0 ? .orange : .green
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                servicesPanel
                Divider()
                outdatedPanel
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

    // MARK: - Subviews

    private var servicesPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Services", systemImage: "gearshape.2.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            if entry.runningServiceNames.isEmpty {
                Text("No services running")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entry.runningServiceNames.prefix(4), id: \.self) { name in
                    serviceRow(name)
                }
                if entry.runningServiceNames.count > 4 {
                    Text("+\(entry.runningServiceNames.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var outdatedPanel: some View {
        VStack(spacing: 8) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.title2)
                .foregroundStyle(outdatedTint)

            Text("\(entry.outdatedCount)")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Outdated")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func serviceRow(_ name: String) -> some View {
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

#Preview(as: .systemMedium) {
    CellarWidget()
} timeline: {
    CellarWidgetEntry.placeholder
}
