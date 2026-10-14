import Foundation

extension ProcessInfo {
    /// Whether this process renders Xcode previews, which must not write
    /// logs or start real background work.
    var isRunningForPreviews: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}
