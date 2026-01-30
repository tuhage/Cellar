import SwiftUI
import WidgetKit

struct CellarWidgetMediumView: View {
    let entry: CellarWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            // Left: Running services
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
                        HStack(spacing: 4) {
                            Circle()
                                .fill(.green)
                                .frame(width: 6, height: 6)
                            Text(name)
                                .font(.caption2)
                                .lineLimit(1)
                        }
                    }
                    if entry.runningServiceNames.count > 4 {
                        Text("+\(entry.runningServiceNames.count - 4) more")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            // Right: Outdated count
            VStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundStyle(entry.outdatedCount > 0 ? .orange : .green)

                Text("\(entry.outdatedCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Outdated")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "cellar://dashboard"))
    }
}
