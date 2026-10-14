import CellarCore
import WidgetKit

/// Keeps the widget's App Group snapshot in step with the app's data, so the
/// widget is current no matter which page is open.
@MainActor
enum WidgetSnapshotService {

    static func update(formulae: [Formula], casks: [Cask], services: [BrewServiceItem], taps: [Tap]) {
        let summary = SystemSummary.current(formulae: formulae, casks: casks, services: services, taps: taps)
        WidgetSnapshot.from(summary: summary, services: services).save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
