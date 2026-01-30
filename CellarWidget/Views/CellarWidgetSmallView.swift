import SwiftUI
import WidgetKit

struct CellarWidgetSmallView: View {
    let entry: CellarWidgetEntry

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "gearshape.2.fill")
                .font(.title)
                .foregroundStyle(.blue)

            Text("\(entry.runningServices)")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text(entry.runningServices == 1 ? "Service Running" : "Services Running")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .widgetURL(URL(string: "cellar://services"))
    }
}
