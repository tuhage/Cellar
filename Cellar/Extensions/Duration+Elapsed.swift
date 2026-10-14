import Foundation

extension Duration {
    /// "1:05" — how long an operation or step has been running.
    static func elapsed(from start: Date, to end: Date) -> String {
        seconds(max(0, end.timeIntervalSince(start))).formatted(.time(pattern: .minuteSecond))
    }
}
