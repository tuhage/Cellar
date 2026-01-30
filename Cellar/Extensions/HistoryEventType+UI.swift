import SwiftUI
import CellarCore

extension HistoryEventType {
    var color: Color {
        switch self {
        case .installed: .green
        case .uninstalled: .red
        case .upgraded: .blue
        case .serviceStarted: .orange
        case .serviceStopped: .secondary
        case .cleanup: .purple
        }
    }
}
