import WidgetKit
import SwiftUI

@main
struct CellarWidget: Widget {
    let kind: String = "CellarWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CellarWidgetProvider()) { entry in
            CellarWidgetView(entry: entry)
        }
        .configurationDisplayName("Cellar")
        .description("Monitor your Homebrew services and packages.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CellarWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: CellarWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            CellarWidgetSmallView(entry: entry)
        case .systemMedium:
            CellarWidgetMediumView(entry: entry)
        case .systemLarge:
            CellarWidgetLargeView(entry: entry)
        default:
            CellarWidgetSmallView(entry: entry)
        }
    }
}

#Preview(as: .systemSmall) {
    CellarWidget()
} timeline: {
    CellarWidgetEntry.placeholder
}

#Preview(as: .systemMedium) {
    CellarWidget()
} timeline: {
    CellarWidgetEntry.placeholder
}

#Preview(as: .systemLarge) {
    CellarWidget()
} timeline: {
    CellarWidgetEntry.placeholder
}
