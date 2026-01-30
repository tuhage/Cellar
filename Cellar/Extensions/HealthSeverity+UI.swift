import SwiftUI
import CellarCore

extension HealthSeverity {
    var color: Color {
        switch self {
        case .critical: .red
        case .warning: .yellow
        case .info: .green
        }
    }
}
