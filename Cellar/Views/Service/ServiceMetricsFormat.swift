import Foundation
import CellarCore

// Formatting for service metrics, shared by the Services page and the menu bar.

extension ResourceUsage {

    /// "12.5%" of one core — 100% is a full core, as in Activity Monitor.
    static func formattedCPU(_ percent: Double) -> String {
        (percent / 100).formatted(.percent.precision(.fractionLength(1)))
    }

    static func formattedMemory(_ bytes: Int64) -> String {
        bytes.formatted(.byteCount(style: .memory))
    }

    var cpuText: String { Self.formattedCPU(cpuPercent) }
    var memoryText: String { Self.formattedMemory(memoryBytes) }
}

extension Date {

    /// Time since this date: "3 hr", or with more units "3 hr, 12 min".
    func formattedUptime(units: Int = 1) -> String {
        Duration.seconds(max(0, Date().timeIntervalSince(self))).formatted(
            // Rounded down, so 5 hr 40 min reads "5 hr", not "6 hr".
            .units(
                allowed: [.days, .hours, .minutes, .seconds],
                width: .abbreviated,
                maximumUnitCount: units,
                fractionalPart: .hide(rounded: .down)
            )
        )
    }
}
