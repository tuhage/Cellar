import WidgetKit
import CellarCore

struct CellarWidgetEntry: TimelineEntry {
    let date: Date
    private let snapshot: WidgetSnapshot

    var totalFormulae: Int { snapshot.totalFormulae }
    var totalCasks: Int { snapshot.totalCasks }
    var runningServices: Int { snapshot.runningServices }
    var totalServices: Int { snapshot.totalServices }
    var outdatedCount: Int { snapshot.outdatedCount }
    var runningServiceNames: [String] { snapshot.runningServiceNames }
    var outdatedPackageNames: [String] { snapshot.outdatedPackageNames }

    init(date: Date, snapshot: WidgetSnapshot) {
        self.date = date
        self.snapshot = snapshot
    }

    static let placeholder = CellarWidgetEntry(date: .now, snapshot: .preview)

    static let empty = CellarWidgetEntry(
        date: .now,
        snapshot: WidgetSnapshot(
            totalFormulae: 0,
            totalCasks: 0,
            runningServices: 0,
            totalServices: 0,
            outdatedCount: 0,
            runningServiceNames: [],
            outdatedPackageNames: []
        )
    )
}
