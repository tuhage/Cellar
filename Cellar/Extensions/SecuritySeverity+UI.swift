import SwiftUI
import CellarCore

extension SecuritySeverity {
    var color: Color {
        switch self {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .blue
        }
    }
}
