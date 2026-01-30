import WidgetKit
import CellarCore

struct CellarWidgetEntry: TimelineEntry {
    let date: Date
    let totalFormulae: Int
    let totalCasks: Int
    let runningServices: Int
    let totalServices: Int
    let outdatedCount: Int
    let runningServiceNames: [String]
    let outdatedPackageNames: [String]

    static var placeholder: CellarWidgetEntry {
        CellarWidgetEntry(
            date: .now,
            totalFormulae: 142,
            totalCasks: 38,
            runningServices: 4,
            totalServices: 7,
            outdatedCount: 5,
            runningServiceNames: ["postgresql@16", "redis", "nginx", "dnsmasq"],
            outdatedPackageNames: ["openssl@3", "node", "python@3.12", "git", "wget"]
        )
    }

    static var empty: CellarWidgetEntry {
        CellarWidgetEntry(
            date: .now,
            totalFormulae: 0,
            totalCasks: 0,
            runningServices: 0,
            totalServices: 0,
            outdatedCount: 0,
            runningServiceNames: [],
            outdatedPackageNames: []
        )
    }

    init(date: Date, snapshot: WidgetSnapshot) {
        self.date = date
        self.totalFormulae = snapshot.totalFormulae
        self.totalCasks = snapshot.totalCasks
        self.runningServices = snapshot.runningServices
        self.totalServices = snapshot.totalServices
        self.outdatedCount = snapshot.outdatedCount
        self.runningServiceNames = snapshot.runningServiceNames
        self.outdatedPackageNames = snapshot.outdatedPackageNames
    }

    init(
        date: Date,
        totalFormulae: Int,
        totalCasks: Int,
        runningServices: Int,
        totalServices: Int,
        outdatedCount: Int,
        runningServiceNames: [String],
        outdatedPackageNames: [String]
    ) {
        self.date = date
        self.totalFormulae = totalFormulae
        self.totalCasks = totalCasks
        self.runningServices = runningServices
        self.totalServices = totalServices
        self.outdatedCount = outdatedCount
        self.runningServiceNames = runningServiceNames
        self.outdatedPackageNames = outdatedPackageNames
    }
}
