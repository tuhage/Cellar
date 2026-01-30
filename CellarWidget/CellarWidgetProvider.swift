import WidgetKit
import CellarCore

struct CellarWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CellarWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (CellarWidgetEntry) -> Void) {
        let entry = loadEntry()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CellarWidgetEntry>) -> Void) {
        let entry = loadEntry()
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func loadEntry() -> CellarWidgetEntry {
        guard let snapshot = WidgetSnapshot.load() else {
            return .empty
        }
        return CellarWidgetEntry(date: .now, snapshot: snapshot)
    }
}
